import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../models/snippet_stats.dart';
import '../models/sync_status.dart';
import '../models/tag_filter.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/paste_service.dart';
import '../services/target_window_service.dart';
import '../utils/search_index.dart';
import '../utils/search_query.dart';
import '../utils/terminal_paste_guard.dart';

/// 片段的一个历史版本（提交信息 + 该提交中的片段快照）
class SnippetVersion {
  final GitCommitInfo commit;
  final Snippet snippet;
  const SnippetVersion({required this.commit, required this.snippet});
}

/// 片段状态管理
///
/// 管理片段定义的加载、搜索、排序、CRUD 和 Git 同步，
/// 以及本机使用统计（不同步，见 ADR-0001）。
/// 测试时可通过构造方法注入 mock 的 StorageService 和 GitService。
/// 粘贴函数签名（测试时可注入 mock）
typedef PasteFn = Future<PasteOutcome> Function(String text);
typedef CopyFn = Future<bool> Function(String text);

/// 目标窗口进程名获取函数（测试时可注入 mock）
typedef TargetProcessNameFn = String? Function();

class SnippetProvider extends ChangeNotifier {
  final StorageService _storage;
  final GitService _git;
  final PasteFn _paste;
  final CopyFn _copy;
  final TargetProcessNameFn _targetProcessName;
  final _uuid = Uuid();

  List<Snippet> _snippets = [];
  List<Snippet> _filteredSnippets = [];
  Map<String, SnippetStats> _stats = {};

  /// 片段 id → 预计算的检索串（含拼音），加载/变更时重建，按键时只做子串比较
  Map<String, String> _searchIndex = {};
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  String? _notice;
  bool _isSearchVisible = false;

  SnippetProvider({
    StorageService? storage,
    GitService? git,
    PasteFn? paste,
    CopyFn? copy,
    TargetProcessNameFn? targetProcessName,
  })  : _storage = storage ?? (throw ArgumentError.notNull('storage')),
        _git = git ?? (throw ArgumentError.notNull('git')),
        _paste = paste ?? PasteService.paste,
        _copy = copy ?? PasteService.copy,
        _targetProcessName =
            targetProcessName ?? (() => TargetWindowService.processName);

  // ========== Getters ==========

  List<Snippet> get snippets => _snippets;
  List<Snippet> get filteredSnippets => _filteredSnippets;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 一次性提示信息（如粘贴降级为仅复制），下次呼出搜索框时清除
  String? get notice => _notice;
  bool get isSearchVisible => _isSearchVisible;

  /// 从搜索窗进入片段编辑器时保持主窗口可见，供窗口失焦策略读取。
  bool get isSnippetEditorOpen => _isSnippetEditorOpen;
  bool _isSnippetEditorOpen = false;

  void beginSnippetEditor() {
    _isSnippetEditorOpen = true;
  }

  void endSnippetEditor() {
    _isSnippetEditorOpen = false;
  }

  /// 全局快捷键注册失败信息；null 表示注册正常
  String? get hotkeyError => _hotkeyError;
  String? _hotkeyError;

  /// 更新快捷键注册状态（注册成功传 null 清除错误）
  void setHotkeyError(String? message) {
    _hotkeyError = message;
    notifyListeners();
  }

  /// Git 同步状态（供主窗常驻指示与设置页错误详情）
  SyncStatus get syncStatus => _syncStatus;
  SyncStatus _syncStatus = SyncStatus.initial;

  void _setSyncing() {
    _syncStatus = _syncStatus.copyWith(
      state: SyncState.syncing,
      lastSuccessAt: _syncStatus.lastSuccessAt,
    );
    notifyListeners();
  }

  void _setSyncOk() {
    _syncStatus = SyncStatus(
      state: SyncState.ok,
      lastSuccessAt: DateTime.now(),
    );
    notifyListeners();
  }

  void _setSyncError(String message) {
    _syncStatus = SyncStatus(
      state: SyncState.error,
      message: message,
      lastSuccessAt: _syncStatus.lastSuccessAt,
    );
    notifyListeners();
  }

  /// 某条片段在本机的使用统计（从未使用过返回 SnippetStats.zero）
  SnippetStats statsFor(String id) => _stats[id] ?? SnippetStats.zero;

  // ========== 初始化 ==========

  /// 加载片段定义与本机使用统计（不执行 Git 同步）
  Future<void> loadSnippets() async {
    _snippets = await _storage.loadSnippets();
    _stats = await _storage.loadStats();
    _searchIndex = {
      for (final s in _snippets) s.id: buildSearchIndex(s),
    };
    _applyFilter();
    notifyListeners();
  }

  /// 完整初始化：确保数据目录 + Git init + 启动同步 + 加载片段
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dataDir = await _storage.getDataDirPath();
      await _storage.ensureDataDir();

      // Git 初始化
      await _git.init(dataDir);

      // 启动时同步
      if (_hasRemote) _setSyncing();
      final syncError = await _git.syncOnStart(dataDir);
      if (syncError != null) {
        _error = syncError;
        _setSyncError(syncError);
      } else if (_hasRemote) {
        _setSyncOk();
      }

      await loadSnippets();
    } catch (e) {
      _error = '初始化失败: $e';
      _setSyncError('初始化失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 手动「立即同步」：拉取远端变更并重新加载片段列表。
  ///
  /// 返回 true 表示同步成功；失败时错误信息写入 [error]。
  Future<bool> syncNow() async {
    _error = null;
    _setSyncing();
    try {
      final dataDir = await _storage.getDataDirPath();
      final pullError = await _git.pull(dataDir);
      if (pullError != null) {
        _error = pullError;
        _setSyncError(pullError);
        return false;
      }
      await loadSnippets();
      _setSyncOk();
      return true;
    } catch (e) {
      _error = '同步失败: $e';
      _setSyncError('同步失败: $e');
      return false;
    }
  }

  /// 是否已配置 Git 远端（读偏好失败时保守视为未配置）
  bool get _hasRemote {
    try {
      return _storage.hasGitRemote;
    } catch (_) {
      return false;
    }
  }

  // ========== 搜索 ==========

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  /// 当前查询的自由关键词（去掉 #tag），供列表名称高亮命中字符
  String get searchText => parseSearchQuery(_searchQuery).text;

  // ========== 标签过滤（侧栏） ==========

  TagFilter _tagFilter = const TagFilter.all();

  /// 侧栏当前选中的标签过滤条件，与关键词搜索叠加（AND）
  TagFilter get tagFilter => _tagFilter;

  void setTagFilter(TagFilter filter) {
    _tagFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  /// 库中全部标签：不区分大小写去重（保留首次出现的写法），按字典序排列
  List<String> get allTags {
    final seen = <String>{};
    final tags = <String>[];
    for (final s in _snippets) {
      for (final t in s.tags) {
        if (seen.add(t.toLowerCase())) tags.add(t);
      }
    }
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  /// 库中是否存在无标签片段（决定侧栏「无标签」项显隐）
  bool get hasUntaggedSnippets => _snippets.any((s) => s.tags.isEmpty);

  void _applyFilter() {
    final base = _tagFilter.isAll
        ? _snippets
        : _snippets.where((s) => _tagFilter.matches(s.tags)).toList();
    final query = parseSearchQuery(_searchQuery);
    if (query.isEmpty) {
      _filteredSnippets = List.from(base);
    } else {
      _filteredSnippets = base.where((snippet) {
        // #tag 约束按片段标签精确过滤
        if (!matchesTags(snippet.tags, query.tags)) return false;
        if (query.text.isEmpty) return true;
        final index = _searchIndex[snippet.id] ??= buildSearchIndex(snippet);
        return index.contains(query.text);
      }).toList();
    }
    _sortSnippets();
  }

  // ========== 排序 ==========

  void _sortSnippets() {
    final now = DateTime.now();
    // 每轮排序前算好各片段得分，避免 sort 比较器里重复计算
    final scores = {
      for (final s in _filteredSnippets) s.id: statsFor(s.id).frecencyScore(now),
    };
    _filteredSnippets.sort((a, b) {
      // 置顶项恒排最前
      final pinA = statsFor(a.id).pinned;
      final pinB = statsFor(b.id).pinned;
      if (pinA != pinB) return pinA ? -1 : 1;
      // frecency 降序：近期使用权重高，随时间指数衰减
      final scoreCmp = scores[b.id]!.compareTo(scores[a.id]!);
      if (scoreCmp != 0) return scoreCmp;
      final statsA = statsFor(a.id);
      final statsB = statsFor(b.id);
      // 同分按累计频次降序
      final freqCmp = statsB.frequency.compareTo(statsA.frequency);
      if (freqCmp != 0) return freqCmp;
      // 再按最近使用时间降序
      final timeCmp = statsB.lastUsedAt.compareTo(statsA.lastUsedAt);
      if (timeCmp != 0) return timeCmp;
      // 全都没用过：按名称字典序，保证稳定可预期
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  // ========== 终端多行粘贴护栏 ==========

  /// 该片段此刻粘贴是否需要先弹终端多行确认框。
  /// [contentOverride]：模板渲染后的最终粘贴内容（判定以实际粘贴内容为准）。
  bool needsTerminalPasteConfirm(String id, {String? contentOverride}) {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    return shouldConfirmTerminalPaste(
      content: contentOverride ?? _snippets[index].content,
      targetProcessName: _targetProcessName(),
      suppressed: _storage.suppressTerminalPasteWarning,
    );
  }

  /// 用户勾选「不再提醒」
  void suppressTerminalPasteWarning() {
    _storage.suppressTerminalPasteWarning = true;
  }

  // ========== 粘贴（记录本机使用统计，不触发 Git） ==========

  /// 记录片段被使用一次并粘贴。只写本地统计文件（ADR-0001）。
  /// [contentOverride]：占位符模板渲染后的最终内容（不改片段定义本身）。
  Future<void> useSnippet(String id, {String? contentOverride}) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;

    _stats = {..._stats, id: statsFor(id).used(DateTime.now())};
    _applyFilter();
    notifyListeners();

    // 粘贴到目标窗口
    final outcome =
        await _paste(contentOverride ?? _snippets[index].content);
    switch (outcome) {
      case PasteOutcome.pasted:
      case PasteOutcome.copiedOnly:
        break;
      case PasteOutcome.targetLost:
        _notice = '目标窗口已关闭，内容已复制到剪贴板，可手动 Ctrl+V 粘贴';
        notifyListeners();
        break;
      case PasteOutcome.failed:
        _error = '粘贴失败：无法写入剪贴板';
        notifyListeners();
        break;
    }

    // 只持久化本地统计，不涉及 snippets.json 和 Git
    try {
      await _storage.saveStats(_stats);
    } catch (e) {
      _error = '保存使用统计失败: $e';
      notifyListeners();
    }
  }

  /// 记录片段被使用一次并仅复制到剪贴板。返回是否复制成功。
  /// 不触发目标窗口粘贴，因此终端多行护栏不适用。
  Future<bool> copySnippet(String id, {String? contentOverride}) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return false;

    _stats = {..._stats, id: statsFor(id).used(DateTime.now())};
    _applyFilter();
    notifyListeners();

    final copied = await _copy(contentOverride ?? _snippets[index].content);
    if (copied) {
      _notice = '已复制「${_snippets[index].name}」到剪贴板';
    } else {
      _error = '复制失败：无法写入剪贴板';
    }
    notifyListeners();

    try {
      await _storage.saveStats(_stats);
    } catch (e) {
      _error = '保存使用统计失败: $e';
      notifyListeners();
    }
    return copied;
  }

  // ========== CRUD ==========

  /// 添加片段
  Future<void> addSnippet({
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
    bool isTemplate = false,
  }) async {
    final snippet = Snippet(
      id: _uuid.v4(),
      name: name,
      content: content,
      description: description,
      tags: tags,
      isTemplate: isTemplate,
    );

    _snippets = [..._snippets, snippet];
    _searchIndex = {..._searchIndex, snippet.id: buildSearchIndex(snippet)};
    _applyFilter();
    notifyListeners();

    await _persistAndSync('add snippet "${snippet.name}"');
  }

  /// 编辑片段
  Future<void> updateSnippet({
    required String id,
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
    bool? isTemplate,
  }) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final updated = _snippets[index].copyWith(
      name: name,
      content: content,
      description: description,
      tags: tags,
      isTemplate: isTemplate,
    );
    _snippets = [
      ..._snippets.sublist(0, index),
      updated,
      ..._snippets.sublist(index + 1),
    ];
    _searchIndex = {..._searchIndex, updated.id: buildSearchIndex(updated)};
    _applyFilter();
    notifyListeners();

    await _persistAndSync('update snippet "$name"');
  }

  /// 删除片段（同时清理本机统计）
  Future<void> deleteSnippet(String id) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final snippet = _snippets[index];
    _snippets = _snippets.where((s) => s.id != id).toList();
    _searchIndex = {..._searchIndex}..remove(id);
    if (_stats.containsKey(id)) {
      _stats = {..._stats}..remove(id);
      try {
        await _storage.saveStats(_stats);
      } catch (e) {
        // 统计清理失败不阻塞删除本身
      }
    }
    _applyFilter();
    notifyListeners();

    await _persistAndSync('delete snippet "${snippet.name}"');
  }

  /// 切换片段置顶状态（本地统计，不同步 ADR-0001）。
  Future<void> togglePin(String id) async {
    final current = statsFor(id);
    _stats = {..._stats, id: current.withPinned(!current.pinned)};
    _applyFilter();
    notifyListeners();
    try {
      await _storage.saveStats(_stats);
    } catch (e) {
      _error = '保存置顶状态失败: $e';
      notifyListeners();
    }
  }

  bool isPinned(String id) => statsFor(id).pinned;

  // ========== 批量导入 ==========

  /// 库中已有片段的 content 集合（供导入去重）
  Set<String> get existingContents =>
      {for (final s in _snippets) s.content};

  /// 批量导入片段（已由 UI 完成勾选），一次性持久化 + 同步。
  /// 返回实际入库数量。
  Future<int> importSnippets(List<Snippet> incoming) async {
    if (incoming.isEmpty) return 0;
    _snippets = [..._snippets, ...incoming];
    _searchIndex = {
      ..._searchIndex,
      for (final s in incoming) s.id: buildSearchIndex(s),
    };
    _applyFilter();
    notifyListeners();
    await _persistAndSync('import ${incoming.length} snippet(s)');
    return incoming.length;
  }

  /// 用给定 id 生成器创建一条片段（不入库，供导入页构建 incoming 列表）
  Snippet buildSnippet({
    required String name,
    required String content,
    List<String>? tags,
    bool isTemplate = false,
  }) =>
      Snippet(
        id: _uuid.v4(),
        name: name,
        content: content,
        tags: tags,
        isTemplate: isTemplate,
      );

  // ========== 片段历史回滚 ==========

  /// 某条片段的历史版本（从 snippets.json 的提交历史中抽取该 id 存在过的版本）。
  /// 返回 (提交信息, 该提交中的该片段) 列表，最新在前；已删除或不存在的版本跳过。
  Future<List<SnippetVersion>> snippetHistory(String id) async {
    final dataDir = await _storage.getDataDirPath();
    final commits = await _git.fileHistory(dataDir);
    final versions = <SnippetVersion>[];
    final seenContent = <String>{};
    for (final c in commits) {
      final json = await _git.snippetsAtCommit(dataDir, c.hash);
      if (json == null) continue;
      final snippet = _extractSnippet(json, id);
      if (snippet == null) continue;
      // 去重键覆盖 restoreSnippet 恢复的全部字段，jsonEncode 消除拼接歧义
      final key = jsonEncode({
        'name': snippet.name,
        'content': snippet.content,
        'description': snippet.description,
        'tags': snippet.tags,
      });
      if (!seenContent.add(key)) continue;
      versions.add(SnippetVersion(commit: c, snippet: snippet));
    }
    return versions;
  }

  Snippet? _extractSnippet(String snippetsJson, String id) {
    try {
      final list = jsonDecode(snippetsJson) as List<dynamic>;
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        if (map['id'] == id) return Snippet.fromJson(map);
      }
    } catch (_) {
      // 该提交的文件损坏：跳过这个历史点
    }
    return null;
  }

  /// 把某条片段恢复到历史版本（只改这一条，其余不动），随后持久化 + 同步。
  Future<void> restoreSnippet(String id, Snippet historical) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final restored = _snippets[index].copyWith(
      name: historical.name,
      content: historical.content,
      description: historical.description,
      tags: List.from(historical.tags),
    );
    _snippets = [
      ..._snippets.sublist(0, index),
      restored,
      ..._snippets.sublist(index + 1),
    ];
    _searchIndex = {..._searchIndex, restored.id: buildSearchIndex(restored)};
    _applyFilter();
    notifyListeners();
    await _persistAndSync('restore snippet "${restored.name}"');
  }

  // ========== 搜索框显隐 ==========

  void showSearch() {
    _isSearchVisible = true;
    _searchQuery = '';
    // 每次呼出回到「全部」：与清空搜索词一致，保证唤醒后所见即全库
    _tagFilter = const TagFilter.all();
    _notice = null;
    _applyFilter();
    notifyListeners();
  }

  void hideSearch() {
    _isSearchVisible = false;
    _searchQuery = '';
    notifyListeners();
  }

  // ========== 设置页导航（托盘菜单也需要打开设置，故放在 Provider） ==========

  bool _isSettingsOpen = false;
  bool get isSettingsOpen => _isSettingsOpen;

  void openSettings() {
    _isSettingsOpen = true;
    notifyListeners();
  }

  void closeSettings() {
    _isSettingsOpen = false;
    notifyListeners();
  }

  // ========== 内部方法 ==========

  Future<void> _persistAndSync(String commitMessage) async {
    try {
      await _storage.saveSnippets(_snippets);
      final dataDir = await _storage.getDataDirPath();
      if (_hasRemote) _setSyncing();
      final error = await _git.commitAndPush(dataDir, commitMessage);
      if (error != null) {
        _error = error;
        _setSyncError(error);
      } else if (_hasRemote) {
        _setSyncOk();
      }
    } catch (e) {
      _error = '保存失败: $e';
      _setSyncError('保存失败: $e');
    }
  }
}
