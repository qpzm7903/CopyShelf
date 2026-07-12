import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snippet.dart';
import '../models/snippet_stats.dart';
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

  /// 通用字符串偏好读写（供 extension 复用，避免各处直接碰 _p）
  String? rawString(String key) => _p.getString(key);
  void setRawString(String key, String value) => _p.setString(key, value);

  /// 终端多行粘贴确认框的「不再提醒」
  bool get suppressTerminalPasteWarning =>
      _p.getBool(AppConstants.prefKeySuppressTerminalPasteWarning) ?? false;
  set suppressTerminalPasteWarning(bool value) =>
      _p.setBool(AppConstants.prefKeySuppressTerminalPasteWarning, value);

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
    // 确保 .gitignore 排除本地统计文件（ADR-0001：使用统计不同步）
    await _ensureStatsIgnored(dir);
    return dir;
  }

  /// 把 stats.json 写进数据目录的 .gitignore（不存在则创建，存在但缺行则追加）
  Future<void> _ensureStatsIgnored(Directory dir) async {
    final gitignore = File('${dir.path}\\.gitignore');
    const statsLine = AppConstants.statsFileName;
    if (!await gitignore.exists()) {
      await gitignore.writeAsString('$statsLine\n');
      return;
    }
    final content = await gitignore.readAsString();
    final lines = content.split('\n').map((l) => l.trim());
    if (!lines.contains(statsLine)) {
      final separator = content.isEmpty || content.endsWith('\n') ? '' : '\n';
      await gitignore.writeAsString('$content$separator$statsLine\n');
    }
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
    // 多行缩进格式：每条片段占独立行段，git 才能对不同片段的并发编辑做行级合并
    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(snippets.map((c) => c.toJson()).toList());
    await file.writeAsString(content);
  }

  // ========== 使用统计（本地文件，不同步，ADR-0001） ==========

  Future<String> _statsFilePath() async {
    final dir = await getDataDirPath();
    return '$dir\\${AppConstants.statsFileName}';
  }

  Future<Map<String, SnippetStats>> loadStats() async {
    final path = await _statsFilePath();
    final file = File(path);
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return map.map((id, json) => MapEntry(
          id, SnippetStats.fromJson(json as Map<String, dynamic>)));
    } catch (e) {
      // 统计文件损坏不致命：丢弃统计，从零开始
      return {};
    }
  }

  Future<void> saveStats(Map<String, SnippetStats> stats) async {
    final path = await _statsFilePath();
    final file = File(path);
    final content =
        jsonEncode(stats.map((id, s) => MapEntry(id, s.toJson())));
    await file.writeAsString(content);
  }
}
