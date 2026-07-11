import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/snippet_stats.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/services/git_service.dart';
import 'package:copyshelf/services/paste_service.dart';

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

void main() {
  late MockStorageService storage;
  late MockGitService git;
  late SnippetProvider provider;

  setUp(() {
    storage = MockStorageService();
    git = MockGitService();
    provider = SnippetProvider(storage: storage, git: git);
  });

  group('SnippetProvider', () {
    test('initial state is empty', () {
      expect(provider.snippets, isEmpty);
      expect(provider.filteredSnippets, isEmpty);
      expect(provider.searchQuery, '');
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('loadSnippets loads definitions and stats from storage', () async {
      storage.saveSnippets([
        Snippet(id: '1', name: 'test', content: 'content'),
      ]);
      storage.seedStats({
        '1': SnippetStats(frequency: 3, lastUsedAt: DateTime(2026, 7, 1)),
      });

      await provider.loadSnippets();

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'test');
      expect(provider.statsFor('1').frequency, 3);
    });

    test('addSnippet adds to list, persists, and commits exactly once',
        () async {
      await provider.addSnippet(
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改',
        tags: ['git'],
      );

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'git amend');
      expect(storage.storedSnippets.length, 1);
      expect(git.commitAndPushCallCount, 1);
      // 数据仓库 commit 消息不用 conventional-commit 前缀
      expect(git.commitMessages[0].startsWith('feat:'), isFalse);
    });

    test('updateSnippet edits and commits exactly once', () async {
      await provider.addSnippet(name: 'old', content: 'old content');
      git.commitAndPushCallCount = 0;

      await provider.updateSnippet(
        id: provider.snippets[0].id,
        name: 'new',
        content: 'new content',
        description: 'updated',
        tags: ['git'],
      );

      expect(provider.snippets[0].name, 'new');
      expect(provider.snippets[0].content, 'new content');
      expect(git.commitAndPushCallCount, 1);
    });

    test('deleteSnippet removes from list and commits exactly once', () async {
      await provider.addSnippet(name: 'snip1', content: 'c1');
      await provider.addSnippet(name: 'snip2', content: 'c2');
      git.commitAndPushCallCount = 0;

      await provider.deleteSnippet(provider.snippets[0].id);

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'snip2');
      expect(git.commitAndPushCallCount, 1);
    });

    test('useSnippet updates local stats and does NOT touch git (ADR-0001)',
        () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      final id = provider.snippets[0].id;
      git.commitAndPushCallCount = 0;
      storage.saveSnippetsCallCount = 0;
      final before = DateTime.now().add(const Duration(seconds: -1));

      await provider.useSnippet(id);

      expect(provider.statsFor(id).frequency, 1);
      expect(provider.statsFor(id).lastUsedAt.isAfter(before), isTrue);
      expect(storage.saveStatsCallCount, 1);
      // 粘贴不触发任何 Git 操作，也不重写定义文件
      expect(git.commitAndPushCallCount, 0);
      expect(storage.saveSnippetsCallCount, 0);
    });

    test('useSnippet 10 times → zero git operations', () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      final id = provider.snippets[0].id;
      git.commitAndPushCallCount = 0;

      for (int i = 0; i < 10; i++) {
        await provider.useSnippet(id);
      }

      expect(provider.statsFor(id).frequency, 10);
      expect(git.commitAndPushCallCount, 0);
    });

    test('stats update is immutable — old stats object is not mutated',
        () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      final id = provider.snippets[0].id;
      await provider.useSnippet(id);
      final statsBefore = provider.statsFor(id);
      final freqBefore = statsBefore.frequency;

      await provider.useSnippet(id);

      expect(statsBefore.frequency, freqBefore);
      expect(provider.statsFor(id).frequency, freqBefore + 1);
      expect(identical(statsBefore, provider.statsFor(id)), isFalse);
    });

    test('persisted snippets.json data has no stats fields', () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      await provider.useSnippet(provider.snippets[0].id);

      final json = storage.storedSnippets[0].toJson();
      expect(json.containsKey('frequency'), isFalse);
      expect(json.containsKey('lastUsedAt'), isFalse);
    });

    test('sorting by frequency desc, then lastUsedAt desc', () async {
      await provider.addSnippet(name: 'low', content: 'c');
      await provider.addSnippet(name: 'high', content: 'c');

      final highId =
          provider.snippets.firstWhere((s) => s.name == 'high').id;
      for (int i = 0; i < 3; i++) {
        await provider.useSnippet(highId);
      }

      provider.setSearchQuery('');
      expect(provider.filteredSnippets[0].name, 'high');
      expect(provider.filteredSnippets[1].name, 'low');
    });

    test('snippet synced from remote without local stats sorts last',
        () async {
      storage.saveSnippets([
        Snippet(id: 'remote-new', name: 'remote', content: 'c'),
        Snippet(id: 'local-used', name: 'local', content: 'c'),
      ]);
      storage.seedStats({
        'local-used':
            SnippetStats(frequency: 5, lastUsedAt: DateTime(2026, 7, 1)),
      });

      await provider.loadSnippets();

      expect(provider.filteredSnippets[0].name, 'local');
      expect(provider.filteredSnippets[1].name, 'remote');
      expect(provider.statsFor('remote-new').frequency, 0);
    });

    test('orphan stats (snippet deleted on another device) are ignored',
        () async {
      storage.saveSnippets([
        Snippet(id: '1', name: 'alive', content: 'c'),
      ]);
      storage.seedStats({
        '1': SnippetStats(frequency: 1, lastUsedAt: DateTime(2026, 7, 1)),
        'ghost':
            SnippetStats(frequency: 99, lastUsedAt: DateTime(2026, 7, 2)),
      });

      await provider.loadSnippets();

      expect(provider.snippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'alive');
    });

    test('deleteSnippet also cleans up its local stats', () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      final id = provider.snippets[0].id;
      await provider.useSnippet(id);
      expect(storage.storedStats.containsKey(id), isTrue);

      await provider.deleteSnippet(id);

      expect(storage.storedStats.containsKey(id), isFalse);
    });

    test('search filters by name', () async {
      await provider.addSnippet(name: 'git push', content: 'git push origin');
      await provider.addSnippet(
          name: 'docker build', content: 'docker build .');
      await provider.addSnippet(name: 'git pull', content: 'git pull origin');

      provider.setSearchQuery('git');

      expect(provider.filteredSnippets.length, 2);
      expect(provider.filteredSnippets.every((s) => s.name.contains('git')),
          isTrue);
    });

    test('search filters by description', () async {
      await provider.addSnippet(
        name: 'deploy',
        content: './deploy.sh',
        description: '部署到生产环境',
      );
      await provider.addSnippet(
        name: 'test',
        content: 'flutter test',
        description: '运行测试',
      );

      provider.setSearchQuery('部署');

      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'deploy');
    });

    test('search filters by tags', () async {
      await provider
          .addSnippet(name: 'snip1', content: 'c1', tags: ['git', '常用']);
      await provider
          .addSnippet(name: 'snip2', content: 'c2', tags: ['docker']);

      provider.setSearchQuery('docker');

      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'snip2');
    });

    test('search is case-insensitive', () async {
      await provider.addSnippet(name: 'Git Push', content: 'c');
      await provider.addSnippet(name: 'DOCKER BUILD', content: 'c');

      provider.setSearchQuery('git');

      expect(provider.filteredSnippets.length, 1);
    });

    test('empty search returns all snippets', () async {
      await provider.addSnippet(name: 'a', content: 'c');
      await provider.addSnippet(name: 'b', content: 'c');
      await provider.addSnippet(name: 'c', content: 'c');

      provider.setSearchQuery('');

      expect(provider.filteredSnippets.length, 3);
    });

    test('showSearch clears query and sets visible', () {
      provider.setSearchQuery('test');
      provider.showSearch();

      expect(provider.searchQuery, '');
      expect(provider.isSearchVisible, isTrue);
    });

    test('CRUD updates are persisted', () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      expect(storage.storedSnippets.length, 1);

      await provider.updateSnippet(
        id: storage.storedSnippets[0].id,
        name: 'updated',
        content: 'u',
      );
      expect(storage.storedSnippets[0].name, 'updated');

      await provider.deleteSnippet(storage.storedSnippets[0].id);
      expect(storage.storedSnippets, isEmpty);
    });

    test('addSnippet with empty tags results in empty tags', () async {
      await provider.addSnippet(name: 'snip', content: 'c');
      expect(provider.snippets[0].tags, []);
    });
  });

  group('SnippetProvider 拼音关键词匹配', () {
    test('中文名可被全拼、首字母、中文子串命中', () async {
      await provider.addSnippet(name: '回复话术-催发货', content: '亲，仓库已加急～');
      await provider.addSnippet(name: 'git amend', content: 'git commit --amend');

      for (final query in ['huifu', 'hf', '回复']) {
        provider.setSearchQuery(query);
        expect(provider.filteredSnippets.length, 1,
            reason: 'query "$query" 应恰好命中中文片段');
        expect(provider.filteredSnippets[0].name, '回复话术-催发货');
      }
    });

    test('英文片段子串匹配不回归', () async {
      await provider.addSnippet(name: 'git amend', content: 'c');
      await provider.addSnippet(name: '回复话术', content: 'c');

      provider.setSearchQuery('amend');

      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'git amend');
    });

    test('纯英文名不做拼音转换：hf 不误命中 git amend', () async {
      await provider.addSnippet(name: 'git amend', content: 'c');

      provider.setSearchQuery('hf');

      expect(provider.filteredSnippets, isEmpty);
    });

    test('description 与 tags 上的拼音命中', () async {
      await provider.addSnippet(
        name: 'deploy',
        content: './deploy.sh',
        description: '部署到生产环境',
        tags: ['运维'],
      );
      await provider.addSnippet(name: 'test', content: 'c');

      provider.setSearchQuery('bushu'); // description 全拼
      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'deploy');

      provider.setSearchQuery('yw'); // tag 首字母
      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'deploy');
    });

    test('中英混合名称：中文部分拼音可命中', () async {
      await provider.addSnippet(name: 'prompt-重构代码', content: 'c');

      provider.setSearchQuery('zhonggou');
      expect(provider.filteredSnippets.length, 1);

      provider.setSearchQuery('prompt');
      expect(provider.filteredSnippets.length, 1);
    });

    test('编辑片段后检索索引同步更新', () async {
      await provider.addSnippet(name: '回复话术', content: 'c');
      final id = provider.snippets[0].id;

      await provider.updateSnippet(id: id, name: '道歉模板', content: 'c');

      provider.setSearchQuery('huifu');
      expect(provider.filteredSnippets, isEmpty);
      provider.setSearchQuery('daoqian');
      expect(provider.filteredSnippets.length, 1);
    });
  });

  group('SnippetProvider paste outcomes', () {
    test('targetLost sets user-visible notice, stats still updated', () async {
      final p = SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.targetLost,
      );
      await p.addSnippet(name: 'snip', content: 'c');

      await p.useSnippet(p.snippets[0].id);

      expect(p.notice, isNotNull);
      expect(p.notice, contains('已复制'));
      expect(p.statsFor(p.snippets[0].id).frequency, 1);
    });

    test('pasted leaves no notice', () async {
      final p = SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.pasted,
      );
      await p.addSnippet(name: 'snip', content: 'c');

      await p.useSnippet(p.snippets[0].id);

      expect(p.notice, isNull);
      expect(p.error, isNull);
    });

    test('copiedOnly (non-Windows) is silent', () async {
      final p = SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.copiedOnly,
      );
      await p.addSnippet(name: 'snip', content: 'c');

      await p.useSnippet(p.snippets[0].id);

      expect(p.notice, isNull);
      expect(p.error, isNull);
    });

    test('failed sets error', () async {
      final p = SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.failed,
      );
      await p.addSnippet(name: 'snip', content: 'c');

      await p.useSnippet(p.snippets[0].id);

      expect(p.error, isNotNull);
    });

    test('showSearch clears previous notice', () async {
      final p = SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.targetLost,
      );
      await p.addSnippet(name: 'snip', content: 'c');
      await p.useSnippet(p.snippets[0].id);
      expect(p.notice, isNotNull);

      p.showSearch();

      expect(p.notice, isNull);
    });
  });
}
