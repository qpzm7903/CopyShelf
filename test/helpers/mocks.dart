import 'dart:io';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/snippet_stats.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/services/git_service.dart';

/// Mock StorageService for testing
class MockStorageService extends StorageService {
  List<Snippet> _storedSnippets = [];
  Map<String, SnippetStats> _storedStats = {};
  int saveSnippetsCallCount = 0;
  int saveStatsCallCount = 0;

  MockStorageService() : super();

  @override
  Future<List<Snippet>> loadSnippets() async {
    return List.from(_storedSnippets);
  }

  @override
  Future<void> saveSnippets(List<Snippet> snippets) async {
    saveSnippetsCallCount++;
    _storedSnippets = List.from(snippets);
  }

  @override
  Future<Map<String, SnippetStats>> loadStats() async {
    return Map.from(_storedStats);
  }

  @override
  Future<void> saveStats(Map<String, SnippetStats> stats) async {
    saveStatsCallCount++;
    _storedStats = Map.from(stats);
  }

  bool hasRemote = false;

  @override
  bool get hasGitRemote => hasRemote;

  bool _suppressTerminalPasteWarning = false;

  @override
  bool get suppressTerminalPasteWarning => _suppressTerminalPasteWarning;

  @override
  set suppressTerminalPasteWarning(bool value) =>
      _suppressTerminalPasteWarning = value;

  @override
  Future<String> getDataDirPath() async => '/test/data';

  @override
  Future<Directory> ensureDataDir({String? customPath}) async =>
      Directory('/test/data');

  List<Snippet> get storedSnippets => _storedSnippets;
  Map<String, SnippetStats> get storedStats => _storedStats;

  void seedStats(Map<String, SnippetStats> stats) {
    _storedStats = Map.from(stats);
  }
}

/// Mock GitService for testing — 记录 commitAndPush 调用
class MockGitService extends GitService {
  int commitAndPushCallCount = 0;
  final List<String> commitMessages = [];

  MockGitService() : super();

  @override
  Future<void> init(String dataDir) async {}

  @override
  Future<String?> commitAndPush(String dataDir, String message) async {
    commitAndPushCallCount++;
    commitMessages.add(message);
    return null;
  }

  @override
  Future<String?> syncOnStart(String dataDir) async => null;

  @override
  Future<String?> pull(String dataDir) async => null;
}
