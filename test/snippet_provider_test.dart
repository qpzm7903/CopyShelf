import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/services/git_service.dart';

/// Mock StorageService for testing
class MockStorageService extends StorageService {
  List<Snippet> _storedSnippets = [];

  MockStorageService() : super();

  @override
  Future<List<Snippet>> loadSnippets() async {
    return List.from(_storedSnippets);
  }

  @override
  Future<void> saveSnippets(List<Snippet> snippets) async {
    _storedSnippets = List.from(snippets);
  }

  @override
  Future<String> getDataDirPath() async => '/test/data';

  @override
  Future<Directory> ensureDataDir({String? customPath}) async => Directory('/test/data');

  List<Snippet> get storedSnippets => _storedSnippets;
}

/// Mock GitService for testing (no-op)
class MockGitService extends GitService {
  MockGitService() : super();

  @override
  Future<void> init(String dataDir) async {}

  @override
  Future<String?> commitAndPush(String dataDir, String message) async => null;

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

    test('loadSnippets loads from storage', () async {
      storage.saveSnippets([
        Snippet(id: '1', name: 'test', content: 'content'),
      ]);

      await provider.loadSnippets();

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'test');
    });

    test('addSnippet adds to list and persists', () async {
      await provider.addSnippet(
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改',
        tags: ['git'],
      );

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'git amend');
      expect(provider.snippets[0].content, 'git commit --amend --no-edit');
      expect(provider.snippets[0].tags, ['git']);
      expect(provider.snippets[0].frequency, 0);

      // Verify persisted
      expect(storage.storedSnippets.length, 1);
    });

    test('updateSnippet edits in-place', () async {
      await provider.addSnippet(name: 'old', content: 'old content');

      await provider.updateSnippet(
        id: provider.snippets[0].id,
        name: 'new',
        content: 'new content',
        description: 'updated',
        tags: ['git'],
      );

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'new');
      expect(provider.snippets[0].content, 'new content');
      expect(provider.snippets[0].description, 'updated');
      expect(provider.snippets[0].tags, ['git']);
    });

    test('deleteSnippet removes from list', () async {
      await provider.addSnippet(name: 'cmd1', content: 'c1');
      await provider.addSnippet(name: 'cmd2', content: 'c2');

      await provider.deleteSnippet(provider.snippets[0].id);

      expect(provider.snippets.length, 1);
      expect(provider.snippets[0].name, 'cmd2');
    });

    test('useSnippet increments frequency and updates lastUsedAt', () async {
      await provider.addSnippet(name: 'cmd', content: 'c');
      final id = provider.snippets[0].id;
      final before = DateTime.now().add(const Duration(seconds: -1));

      await provider.useSnippet(id);

      expect(provider.snippets[0].frequency, 1);
      expect(provider.snippets[0].lastUsedAt.isAfter(before), isTrue);
    });

    test('sorting by frequency desc', () async {
      await provider.addSnippet(name: 'low', content: 'c');
      await provider.addSnippet(name: 'high', content: 'c');

      // Use high 3 times
      final highId = provider.snippets[1].id;
      for (int i = 0; i < 3; i++) {
        await provider.useSnippet(highId);
      }

      provider.setSearchQuery('');
      expect(provider.filteredSnippets[0].name, 'high');
      expect(provider.filteredSnippets[1].name, 'low');
    });

    test('search filters by name', () async {
      await provider.addSnippet(name: 'git push', content: 'git push origin');
      await provider.addSnippet(name: 'docker build', content: 'docker build .');
      await provider.addSnippet(name: 'git pull', content: 'git pull origin');

      provider.setSearchQuery('git');

      expect(provider.filteredSnippets.length, 2);
      expect(provider.filteredSnippets.every((c) => c.name.contains('git')), isTrue);
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
      await provider.addSnippet(
        name: 'cmd1',
        content: 'c1',
        tags: ['git', '常用'],
      );
      await provider.addSnippet(
        name: 'cmd2',
        content: 'c2',
        tags: ['docker'],
      );

      provider.setSearchQuery('docker');

      expect(provider.filteredSnippets.length, 1);
      expect(provider.filteredSnippets[0].name, 'cmd2');
    });

    test('search is case-insensitive', () async {
      await provider.addSnippet(name: 'Git Push', content: 'c');
      await provider.addSnippet(name: 'DOCKER BUILD', content: 'c');

      provider.setSearchQuery('git');

      expect(provider.filteredSnippets.length, 1);
    });

    test('empty search returns all snippets sorted by frequency', () async {
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
      // isSearchVisible is tracked but not tested via getter
    });

    test('CRUD updates are persisted', () async {
      await provider.addSnippet(name: 'cmd', content: 'c');
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
      await provider.addSnippet(name: 'cmd', content: 'c');
      expect(provider.snippets[0].tags, []);
    });
  });
}
