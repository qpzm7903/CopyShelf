import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    });
  });


  Future<({SnippetProvider provider, List<String> pasted, MockStorageService storage})>
      pumpOverlay(
    WidgetTester tester, {
    String? targetProcess = 'cmd.exe',
    String content = 'line1\nline2\nline3',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage.saveSnippets(
        [Snippet(id: 'multi', name: 'deploy-script', content: content)]);

    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (text) async {
        pasted.add(text);
        return PasteOutcome.pasted;
      },
      targetProcessName: () => targetProcess,
    );
    await provider.loadSnippets();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SearchOverlay())),
      ),
    );
    await tester.pumpAndSettle();
    return (provider: provider, pasted: pasted, storage: storage);
  }

  Future<void> pressEnter(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  group('终端多行粘贴确认框', () {
    testWidgets('多行片段 + 终端目标：回车先弹确认框，不直接粘贴', (tester) async {
      final ctx = await pumpOverlay(tester);

      await pressEnter(tester);

      expect(find.byKey(const Key('terminal-paste-confirm')), findsOneWidget);
      expect(ctx.pasted, isEmpty);
    });

    testWidgets('确认「仍然粘贴」后执行粘贴', (tester) async {
      final ctx = await pumpOverlay(tester);
      await pressEnter(tester);

      await tester.tap(find.byKey(const Key('terminal-paste-proceed')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['line1\nline2\nline3']);
    });

    testWidgets('取消后不粘贴，搜索窗保持可见', (tester) async {
      final ctx = await pumpOverlay(tester);
      await pressEnter(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(ctx.pasted, isEmpty);
      expect(ctx.provider.isSearchVisible, isFalse); // 初始就是 false，不因取消变化
    });

    testWidgets('勾选「不再提醒」并确认：写入持久化，下次直通', (tester) async {
      final ctx = await pumpOverlay(tester);
      await pressEnter(tester);

      await tester.tap(find.byKey(const Key('terminal-paste-suppress')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal-paste-proceed')));
      await tester.pumpAndSettle();

      expect(ctx.storage.suppressTerminalPasteWarning, isTrue);
      expect(ctx.pasted, hasLength(1));

      // 再次粘贴：不再弹框
      ctx.provider.showSearch();
      await tester.pumpAndSettle();
      await pressEnter(tester);
      expect(find.byKey(const Key('terminal-paste-confirm')), findsNothing);
      expect(ctx.pasted, hasLength(2));
    });

    testWidgets('非终端目标：多行内容直接粘贴不弹框', (tester) async {
      final ctx = await pumpOverlay(tester, targetProcess: 'Code.exe');

      await pressEnter(tester);

      expect(find.byKey(const Key('terminal-paste-confirm')), findsNothing);
      expect(ctx.pasted, hasLength(1));
    });

    testWidgets('单行内容 + 终端目标：直接粘贴不弹框', (tester) async {
      final ctx = await pumpOverlay(tester, content: 'git status');

      await pressEnter(tester);

      expect(find.byKey(const Key('terminal-paste-confirm')), findsNothing);
      expect(ctx.pasted, hasLength(1));
    });

    testWidgets('鼠标点击列表行同样触发终端护栏（回归 bug-M1）', (tester) async {
      final ctx = await pumpOverlay(tester);

      await tester.tap(find.text('deploy-script'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal-paste-confirm')), findsOneWidget);
      expect(ctx.pasted, isEmpty);
    });
  });
}
