import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/command.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';

/// 指令状态管理
///
/// 管理指令的加载、搜索、排序、CRUD 和 Git 同步。
/// 测试时可通过构造方法注入 mock 的 StorageService 和 GitService。
class CommandProvider extends ChangeNotifier {
  final StorageService _storage;
  final GitService _git;
  final _uuid = const Uuid();

  List<Command> _commands = [];
  List<Command> _filteredCommands = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  bool _isSearchVisible = false;

  CommandProvider({
    StorageService? storage,
    GitService? git,
  })  : _storage = storage ?? (throw ArgumentError.notNull('storage')),
        _git = git ?? (throw ArgumentError.notNull('git'));

  // ========== Getters ==========

  List<Command> get commands => _commands;
  List<Command> get filteredCommands => _filteredCommands;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSearchVisible => _isSearchVisible;

  // ========== 初始化 ==========

  /// 加载指令（不执行 Git 同步，供外部管理初始化流程时使用）
  Future<void> loadCommands() async {
    _commands = await _storage.loadCommands();
    _sortCommands();
    _applyFilter();
    notifyListeners();
  }

  /// 完整初始化：确保数据目录 + Git init + 启动同步 + 加载指令
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

      await loadCommands();
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
      _filteredCommands = List.from(_commands);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredCommands = _commands.where((cmd) {
        return cmd.name.toLowerCase().contains(lowerQuery) ||
            cmd.description.toLowerCase().contains(lowerQuery) ||
            cmd.tags.any((t) => t.toLowerCase().contains(lowerQuery));
      }).toList();
    }
    _sortCommands();
  }

  // ========== 排序 ==========

  void _sortCommands() {
    _filteredCommands.sort((a, b) {
      // 先按频率降序
      final freqCmp = b.frequency.compareTo(a.frequency);
      if (freqCmp != 0) return freqCmp;
      // 再按最近使用时间降序
      return b.lastUsedAt.compareTo(a.lastUsedAt);
    });
  }

  // ========== 粘贴（记录使用次数） ==========

  /// 记录指令被使用一次，并同步到 Git
  Future<void> useCommand(String id) async {
    final index = _commands.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _commands[index].frequency++;
    _commands[index].lastUsedAt = DateTime.now();
    _applyFilter();
    notifyListeners();

    // 持久化 + Git 同步
    await _persistAndSync('feat: use command');
  }

  // ========== CRUD ==========

  /// 添加指令
  Future<void> addCommand({
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
  }) async {
    final command = Command(
      id: _uuid.v4(),
      name: name,
      content: content,
      description: description,
      tags: tags,
    );

    _commands.add(command);
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: add command "${command.name}"');
  }

  /// 编辑指令
  Future<void> updateCommand({
    required String id,
    required String name,
    required String content,
    String description = '',
    List<String>? tags,
  }) async {
    final index = _commands.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _commands[index] = _commands[index].copyWith(
      name: name,
      content: content,
      description: description,
      tags: tags,
    );
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: update command "${name}"');
  }

  /// 删除指令
  Future<void> deleteCommand(String id) async {
    final command = _commands.firstWhere((c) => c.id == id);
    _commands.removeWhere((c) => c.id == id);
    _applyFilter();
    notifyListeners();

    await _persistAndSync('feat: delete command "${command.name}"');
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
      await _storage.saveCommands(_commands);
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
