import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snippet.dart';
import '../utils/constants.dart';

/// 本地存储服务
///
/// 管理两个存储层：
/// - `SharedPreferences`：应用设置（快捷键、数据目录、Git 远程地址）
/// - 文件系统：片段数据（snippets.json）
class StorageService {
  static StorageService? _instance;

  SharedPreferences? _prefs;
  bool _initialized = false;

  @visibleForTesting
  StorageService();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService();
    await service._init();
    _instance = service;
    return service;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError(
        'StorageService 尚未初始化，请通过 await StorageService.instance 获取实例。',
      );
    }
    return p;
  }

  // ========== 设置 ==========

  String get dataDir => _p.getString(AppConstants.prefKeyDataDir) ?? '';
  set dataDir(String value) => _p.setString(AppConstants.prefKeyDataDir, value);

  bool get hasDataDir => _p.containsKey(AppConstants.prefKeyDataDir);

  String get hotkey => _p.getString(AppConstants.prefKeyHotkey) ?? AppConstants.defaultHotkey;
  set hotkey(String value) => _p.setString(AppConstants.prefKeyHotkey, value);

  String? get gitRemote => _p.getString(AppConstants.prefKeyGitRemote);
  set gitRemote(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(AppConstants.prefKeyGitRemote, value);
    } else {
      _p.remove(AppConstants.prefKeyGitRemote);
    }
  }

  bool get hasGitRemote => _p.containsKey(AppConstants.prefKeyGitRemote);

  // ========== 数据目录 ==========

  /// 获取数据目录路径。如果尚未设置，返回默认路径。
  Future<String> getDataDirPath() async {
    if (hasDataDir) return dataDir;
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return '${home}\\${AppConstants.defaultDataDirName}';
  }

  /// 确保数据目录和 snippets.json 存在
  Future<Directory> ensureDataDir({String? customPath}) async {
    final dirPath = customPath ?? await getDataDirPath();
    if (customPath != null) {
      dataDir = customPath;
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 确保 snippets.json 存在
    final file = File('${dir.path}\\${AppConstants.snippetsFileName}');
    if (!await file.exists()) {
      await file.writeAsString('[]');
    }
    return dir;
  }

  // ========== 片段 CRUD ==========

  Future<String> _snippetsFilePath() async {
    final dir = await getDataDirPath();
    return '$dir\\${AppConstants.snippetsFileName}';
  }

  Future<List<Snippet>> loadSnippets() async {
    final path = await _snippetsFilePath();
    final file = File(path);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSnippets(List<Snippet> snippets) async {
    final path = await _snippetsFilePath();
    final file = File(path);
    final content = jsonEncode(snippets.map((c) => c.toJson()).toList());
    await file.writeAsString(content);
  }
}
