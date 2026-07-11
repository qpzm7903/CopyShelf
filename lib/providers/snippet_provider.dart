import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../models/snippet_stats.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/paste_service.dart';

/// 片段状态管理
///
/// 管理片段定义的加载、搜索、排序、CRUD 和 Git 同步，
/// 以及本机使用统计（不同步，见 ADR-0001）。
/// 测试时可通过构造方法注入 mock 的 StorageService 和 GitService。
class SnippetProvider extends ChangeNotifier {
  final StorageService _storage;
  final GitService _git;
  final _uuid = Uuid();

  List<Snippet> _snippets = [];
  List<Snippet> _filteredSnippets = [];
  Map<String, SnippetStats> _stats = {};
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  bool _isSearchVisible = false;

  SnippetProvider({
    StorageService? storage,
    GitService? git,
  })  : _storage = storage ?? (throw ArgumentError.notNull('storage')),
        _git = git ?? (throw ArgumentError.notNull('git'));

  // ========== Getters ==========

  List<Snippet> get snippets => _snippets;
  List<Snippet> get filteredSnippets => _filteredSnippets;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSearchVisible => _isSearchVisible;

  /// 某条片段在本机的使用统计（从未使用过返回 SnippetStats.zero）
  SnippetStats statsFor(String id) => _stats[id] ?? SnippetStats.zero;

  // ========== 初始化 ==========

  /// 加载片段定义与本机使用统计（不执行 Git 同步）
  Future<void> loadSnippets() async {
    _snippets = await _storage.loadSnippets();
    _stats = await _storage.loadStats();
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
        return snippet.name.toLowerCase().contains(lowerQuery) ||
            snippet.description.toLowerCase().contains(lowerQuery) ||
            snippet.tags.any((t) => t.toLowerCase().contains(lowerQuery));
      }).toList();
    }
    _sortSnippets();
  }

  // ========== 排序 ==========

  void _sortSnippets() {
    _filteredSnippets.sort((a, b) {
      final statsA = statsFor(a.id);
      final statsB = statsFor(b.id);
      // 先按本机使用频率降序
      final freqCmp = statsB.frequency.compareTo(statsA.frequency);
      if (freqCmp != 0) return freqCmp;
      // 再按最近使用时间降序
      return statsB.lastUsedAt.compareTo(statsA.lastUsedAt);
    });
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
    await PasteService.paste(_snippets[index].content);

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
    _applyFilter();
    notifyListeners();
  }

  void hideSearch() {
    _isSearchVisible = false;
    _searchQuery = '';
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
