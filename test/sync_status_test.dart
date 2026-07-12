import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/sync_status.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/git_service.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

/// 可控返回值的 GitService mock
class ControllableGitService extends GitService {
  String? pullResult;
  String? pushResult;
  String? syncOnStartResult;

  ControllableGitService();

  @override
  Future<void> init(String dataDir) async {}

  @override
  Future<String?> pull(String dataDir) async => pullResult;

  @override
  Future<String?> commitAndPush(String dataDir, String message) async =>
      pushResult;

  @override
  Future<String?> syncOnStart(String dataDir) async => syncOnStartResult;
}

void main() {
  late MockStorageService storage;
  late ControllableGitService git;

  SnippetProvider build() => SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.pasted,
      );

  setUp(() {
    storage = MockStorageService();
    git = ControllableGitService();
  });

  group('SyncStatus 状态机', () {
    test('初始为 idle', () {
      expect(build().syncStatus.state, SyncState.idle);
    });

    test('配置远端时 syncNow 成功：syncing → ok，记录成功时间', () async {
      storage.hasRemote = true;
      final provider = build();

      final future = provider.syncNow();
      // syncNow 内部先置 syncing
      expect(provider.syncStatus.state, SyncState.syncing);

      final ok = await future;
      expect(ok, isTrue);
      expect(provider.syncStatus.state, SyncState.ok);
      expect(provider.syncStatus.lastSuccessAt, isNotNull);
    });

    test('syncNow 失败：进入 error 并保留可读原因', () async {
      storage.hasRemote = true;
      git.pullResult = 'Git 同步冲突：远端和本地修改了同一条片段';
      final provider = build();

      final ok = await provider.syncNow();

      expect(ok, isFalse);
      expect(provider.syncStatus.state, SyncState.error);
      expect(provider.syncStatus.message, contains('冲突'));
    });

    test('先成功后失败：保留上次成功时间', () async {
      storage.hasRemote = true;
      final provider = build();
      await provider.syncNow();
      final firstSuccess = provider.syncStatus.lastSuccessAt;
      expect(firstSuccess, isNotNull);

      git.pullResult = 'push 失败';
      await provider.syncNow();

      expect(provider.syncStatus.state, SyncState.error);
      expect(provider.syncStatus.lastSuccessAt, firstSuccess);
    });

    test('未配置远端时增删改不误报「已同步」', () async {
      storage.hasRemote = false;
      final provider = build();

      await provider.addSnippet(name: 'n', content: 'c');

      expect(provider.syncStatus.state, SyncState.idle);
    });

    test('配置远端时增删改推送成功 → ok', () async {
      storage.hasRemote = true;
      final provider = build();

      await provider.addSnippet(name: 'n', content: 'c');

      expect(provider.syncStatus.state, SyncState.ok);
    });

    test('配置远端时推送失败 → error', () async {
      storage.hasRemote = true;
      git.pushResult = 'Git push 失败：权限不足';
      final provider = build();

      await provider.addSnippet(name: 'n', content: 'c');

      expect(provider.syncStatus.state, SyncState.error);
      expect(provider.syncStatus.message, contains('权限'));
    });

    test('状态变化通知监听者', () async {
      storage.hasRemote = true;
      final provider = build();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.syncNow();

      expect(notified, greaterThan(0));
    });
  });
}

// 让分析器识别 Snippet 引用（addSnippet 内部构造）
// ignore: unused_element
Snippet _unused() => Snippet(id: 'x', name: 'y', content: 'z');
