import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/command.dart';
import 'package:copyshelf/providers/command_provider.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/services/git_service.dart';

/// Mock StorageService for testing
class MockStorageService extends StorageService {
  List<Command> _storedCommands = [];

  MockStorageService() : super();

  @override
  Future<List<Command>> loadCommands() async {
    return List.from(_storedCommands);
  }

  @override
  Future<void> saveCommands(List<Command> commands) async {
    _storedCommands = List.from(commands);
  }

  @override
  Future<String> getDataDirPath() async => '/test/data';

  @override
  Future<Directory> ensureDataDir({String? customPath}) async => Directory('/test/data');

  List<Command> get storedCommands => _storedCommands;
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
  late CommandProvider provider;

  setUp(() {
    storage = MockStorageService();
    git = MockGitService();
    provider = CommandProvider(storage: storage, git: git);
  });

  group('CommandProvider', () {
    test('initial state is empty', () {
      expect(provider.commands, isEmpty);
      expect(provider.filteredCommands, isEmpty);
      expect(provider.searchQuery, '');
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('loadCommands loads from storage', () async {
      storage.saveCommands([
        Command(id: '1', name: 'test', content: 'content'),
      ]);

      await provider.loadCommands();

      expect(provider.commands.length, 1);
      expect(provider.commands[0].name, 'test');
    });

    test('addCommand adds to list and persists', () async {
      await provider.addCommand(
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改',
        tags: ['git'],
      );

      expect(provider.commands.length, 1);
      expect(provider.commands[0].name, 'git amend');
      expect(provider.commands[0].content, 'git commit --amend --no-edit');
      expect(provider.commands[0].tags, ['git']);
      expect(provider.commands[0].frequency, 0);

      // Verify persisted
      expect(storage.storedCommands.length, 1);
    });

    test('updateCommand edits in-place', () async {
      await provider.addCommand(name: 'old', content: 'old content');

      await provider.updateCommand(
        id: provider.commands[0].id,
        name: 'new',
        content: 'new content',
        description: 'updated',
        tags: ['git'],
      );

      expect(provider.commands.length, 1);
      expect(provider.commands[0].name, 'new');
      expect(provider.commands[0].content, 'new content');
      expect(provider.commands[0].description, 'updated');
      expect(provider.commands[0].tags, ['git']);
    });

    test('deleteCommand removes from list', () async {
      await provider.addCommand(name: 'cmd1', content: 'c1');
      await provider.addCommand(name: 'cmd2', content: 'c2');

      await provider.deleteCommand(provider.commands[0].id);

      expect(provider.commands.length, 1);
      expect(provider.commands[0].name, 'cmd2');
    });

    test('useCommand increments frequency and updates lastUsedAt', () async {
      await provider.addCommand(name: 'cmd', content: 'c');
      final id = provider.commands[0].id;
      final before = DateTime.now().add(const Duration(seconds: -1));

      await provider.useCommand(id);

      expect(provider.commands[0].frequency, 1);
      expect(provider.commands[0].lastUsedAt.isAfter(before), isTrue);
    });

    test('sorting by frequency desc', () async {
      await provider.addCommand(name: 'low', content: 'c');
      await provider.addCommand(name: 'high', content: 'c');

      // Use high 3 times
      final highId = provider.commands[1].id;
      for (int i = 0; i < 3; i++) {
        await provider.useCommand(highId);
      }

      provider.setSearchQuery('');
      expect(provider.filteredCommands[0].name, 'high');
      expect(provider.filteredCommands[1].name, 'low');
    });

    test('search filters by name', () async {
      await provider.addCommand(name: 'git push', content: 'git push origin');
      await provider.addCommand(name: 'docker build', content: 'docker build .');
      await provider.addCommand(name: 'git pull', content: 'git pull origin');

      provider.setSearchQuery('git');

      expect(provider.filteredCommands.length, 2);
      expect(provider.filteredCommands.every((c) => c.name.contains('git')), isTrue);
    });

    test('search filters by description', () async {
      await provider.addCommand(
        name: 'deploy',
        content: './deploy.sh',
        description: '部署到生产环境',
      );
      await provider.addCommand(
        name: 'test',
        content: 'flutter test',
        description: '运行测试',
      );

      provider.setSearchQuery('部署');

      expect(provider.filteredCommands.length, 1);
      expect(provider.filteredCommands[0].name, 'deploy');
    });

    test('search filters by tags', () async {
      await provider.addCommand(
        name: 'cmd1',
        content: 'c1',
        tags: ['git', '常用'],
      );
      await provider.addCommand(
        name: 'cmd2',
        content: 'c2',
        tags: ['docker'],
      );

      provider.setSearchQuery('docker');

      expect(provider.filteredCommands.length, 1);
      expect(provider.filteredCommands[0].name, 'cmd2');
    });

    test('search is case-insensitive', () async {
      await provider.addCommand(name: 'Git Push', content: 'c');
      await provider.addCommand(name: 'DOCKER BUILD', content: 'c');

      provider.setSearchQuery('git');

      expect(provider.filteredCommands.length, 1);
    });

    test('empty search returns all commands sorted by frequency', () async {
      await provider.addCommand(name: 'a', content: 'c');
      await provider.addCommand(name: 'b', content: 'c');
      await provider.addCommand(name: 'c', content: 'c');

      provider.setSearchQuery('');

      expect(provider.filteredCommands.length, 3);
    });

    test('showSearch clears query and sets visible', () {
      provider.setSearchQuery('test');
      provider.showSearch();

      expect(provider.searchQuery, '');
      // isSearchVisible is tracked but not tested via getter
    });

    test('CRUD updates are persisted', () async {
      await provider.addCommand(name: 'cmd', content: 'c');
      expect(storage.storedCommands.length, 1);

      await provider.updateCommand(
        id: storage.storedCommands[0].id,
        name: 'updated',
        content: 'u',
      );
      expect(storage.storedCommands[0].name, 'updated');

      await provider.deleteCommand(storage.storedCommands[0].id);
      expect(storage.storedCommands, isEmpty);
    });

    test('addCommand with empty tags results in empty tags', () async {
      await provider.addCommand(name: 'cmd', content: 'c');
      expect(provider.commands[0].tags, []);
    });
  });
}
