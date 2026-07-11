import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../models/snippet_stats.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/paste_service.dart';
import '../services/target_window_service.dart';
import '../utils/search_index.dart';
import '../utils/terminal_paste_guard.dart';

/// 片段状态管理
///
/// 管理片段定义的加载、搜索、排序、CRUD 和 Git 同步，
/// 以及本机使用统计（不同步，见 ADR-0001）。
/// 测试时可通过构造方法注入 mock 的 StorageService 和 GitService。
/// 粘贴函数签名（测试时可注入 mock）
typedef PasteFn = Future<PasteOutcome> Function(String text);

/// 目标窗口进程名获取函数（测试时可注入 mock）
typedef TargetProcessNameFn = String? Function();

class SnippetProvider extends ChangeNotifier {
  final StorageService _storage;
  final GitService _git;
  final PasteFn _paste;
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
    TargetProcessNameFn? targetProcessName,
  })  : _storage = storage ?? (throw ArgumentError.notNull('storage')),
        _git = git ?? (throw ArgumentError.notNull('git')),
        _paste = paste ?? PasteService.paste,
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

  /// 全局快捷键注册失败信息；null 表示注册正常
  String? get hotkeyError => _hotkeyError;
  String? _hotkeyError;

  /// 更新快捷键注册状态（注册成功传 null 清除错误）
  void setHotkeyError(String? message) {
    _hotkeyError = message;
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
      final syncError = await _git.syncOnStart(dataDir);
      if (syncError != null) {
        _error = syncError;
      }

      await loadSnippets();
    } catch (e) {
      _error = '初始化失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 手动「立即同步」：拉取远端变更并重新加载片段列表。
  ///
  /// 返回 true 表示同步成功；失败时错误信息写入 [error]。
  Future<bool> syncNow() async {
    _error = null;
    notifyListeners();
    try {
      final dataDir = await _storage.getDataDirPath();
      final pullError = await _git.pull(dataDir);
      if (pullError != null) {
        _error = pullError;
        notifyListeners();
        return false;
      }
      await loadSnippets();
      return true;
    } catch (e) {
      _error = '同步失败: $e';
      notifyListeners();
      return false;
    }
  }

  // ========== 搜索 ==========

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredSnippets = List.from(_snippets);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredSnippets = _snippets.where((snippet) {
        final index = _searchIndex[snippet.id] ??= buildSearchIndex(snippet);
        return index.contains(lowerQuery);
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

  /// 该片段此刻粘贴是否需要先弹终端多行确认框
  bool needsTerminalPasteConfirm(String id) {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    return shouldConfirmTerminalPaste(
      content: _snippets[index].content,
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
  Future<void> useSnippet(String id) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;

    _stats = {..._stats, id: statsFor(id).used(DateTime.now())};
    _applyFilter();
    notifyListeners();

    // 粘贴到目标窗口
    final outcome = await _paste(_snippets[index].content);
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

  // ========== CRUD ==========

  /// 添加片段
  Future<void> addSnippet({
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
  }) async {
    final snippet = Snippet(
      id: _uuid.v4(),
      name: name,
      content: content,
      description: description,
      tags: tags,
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
  }) async {
    final index = _snippets.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final updated = _snippets[index].copyWith(
      name: name,
      content: content,
      description: description,
      tags: tags,
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

  // ========== 搜索框显隐 ==========

  void showSearch() {
    _isSearchVisible = true;
    _searchQuery = '';
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
      final error = await _git.commitAndPush(dataDir, commitMessage);
      if (error != null) {
        _error = error;
        notifyListeners();
      }
    } catch (e) {
      _error = '保存失败: $e';
      notifyListeners();
    }
  }
}
