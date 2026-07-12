import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:copyshelf/models/sync_status.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/widgets/sync_indicator.dart';

import 'helpers/mocks.dart';

/// 直接控制 syncStatus 的 provider（走真实 syncNow 太重，这里只测渲染）
class _StatusGit extends MockGitService {
  String? pull_;
  @override
  Future<String?> pull(String dataDir) async => pull_;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SnippetProvider> pump(WidgetTester tester,
      {required SyncState want}) async {
    final storage = MockStorageService()..hasRemote = true;
    final git = _StatusGit();
    final provider = SnippetProvider(
      storage: storage,
      git: git,
      paste: (_) async => PasteOutcome.pasted,
    );

    // 用真实路径把状态推到目标态
    if (want == SyncState.ok) {
      await provider.syncNow();
    } else if (want == SyncState.error) {
      git.pull_ = 'Git 同步冲突：请手动解决';
      await provider.syncNow();
    }

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
            home: Scaffold(body: Center(child: SyncIndicator()))),
      ),
    );
    await tester.pump();
    return provider;
  }

  group('SyncIndicator 渲染', () {
    testWidgets('idle 不渲染任何指示', (tester) async {
      await pump(tester, want: SyncState.idle);
      expect(find.byKey(const Key('sync-indicator-ok')), findsNothing);
      expect(find.byKey(const Key('sync-indicator-error')), findsNothing);
      expect(find.byKey(const Key('sync-indicator-syncing')), findsNothing);
    });

    testWidgets('ok 显示已同步', (tester) async {
      await pump(tester, want: SyncState.ok);
      expect(find.byKey(const Key('sync-indicator-ok')), findsOneWidget);
      expect(find.textContaining('已同步'), findsOneWidget);
    });

    testWidgets('error 显示同步失败', (tester) async {
      await pump(tester, want: SyncState.error);
      expect(find.byKey(const Key('sync-indicator-error')), findsOneWidget);
      expect(find.text('同步失败'), findsOneWidget);
    });
  });
}
