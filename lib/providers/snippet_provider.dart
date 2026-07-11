import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/paste_service.dart';

/// 片段状态管理
///
/// 管理片段的加载、搜索、排序、CRUD 和 Git 同步。
/// 测试时可通过构造方法注入 mock 的 StorageService 和 GitService。
class SnippetProvider extends ChangeNotifier {
  final StorageService _storage;
  final GitService _git;
  final _uuid = Uuid();

  List<Snippet> _snippets = [];
  List<Snippet> _filteredSnippets = [];
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

  // ========== 初始化 ==========

  /// 加载片段（不执行 Git 同步，供外部管理初始化流程时使用）
  Future<void> loadSnippets() async {
    _snippets = await _storage.loadSnippets();
    _sortSnippets();
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
      // 先按频率降序
      final freqCmp = b.frequency.compareTo(a.frequency);
      if (freqCmp != 0) return freqCmp;
      // 再按最近使用时间降序
      return b.lastUsedAt.compareTo(a.lastUsedAt);
    });
  }

  // ========== 粘贴（记录使用次数） ==========

  /// 记录片段被使用一次，并同步到 Git
  Future<void> useSnippet(String id) async {
    final index = _snippets.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _snippets[index].frequency++;
    _snippets[index].lastUsedAt = DateTime.now();
    _applyFilter();
    notifyListeners();

    // 粘贴到前台窗口
    await PasteService.paste(_snippets[index].content);

    // 持久化 + Git 同步
    await _persistAndSync('feat: use snippet');
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

    _snippets.add(snippet);
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: add snippet "${snippet.name}"');
  }

  /// 编辑片段
  Future<void> updateSnippet({
    required String id,
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
  }) async {
    final index = _snippets.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _snippets[index] = _snippets[index].copyWith(
      name: name,
      content: content,
      description: description,
      tags: tags,
    );
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: update snippet "${name}"');
  }

  /// 删除片段
  Future<void> deleteSnippet(String id) async {
    final snippet = _snippets.firstWhere((c) => c.id == id);
    _snippets.removeWhere((c) => c.id == id);
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: delete snippet "${snippet.name}"');
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
