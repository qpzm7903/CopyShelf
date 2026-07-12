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


  Future<({SnippetProvider provider, List<String> pasted})> pumpOverlay(
    WidgetTester tester, {
    required String content,
    String? targetProcess,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage.saveSnippets(
        [Snippet(id: 'tpl', name: 'commit-msg', content: content, isTemplate: true)]);

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
    return (provider: provider, pasted: pasted);
  }

  Future<void> pressEnter(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  group('占位符填表粘贴', () {
    testWidgets('含占位符的片段回车弹填表框，填写后粘贴渲染结果', (tester) async {
      final ctx = await pumpOverlay(
          tester, content: 'git commit -m "{message}"');

      await pressEnter(tester);
      expect(find.byKey(const Key('placeholder-form')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('placeholder-field-message')), 'fix: bug');
      await tester.tap(find.byKey(const Key('placeholder-submit')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['git commit -m "fix: bug"']);
    });

    testWidgets('多个占位符逐项填写', (tester) async {
      final ctx = await pumpOverlay(tester, content: '{greeting}, {name}!');

      await pressEnter(tester);
      await tester.enterText(
          find.byKey(const Key('placeholder-field-greeting')), 'Hello');
      await tester.enterText(
          find.byKey(const Key('placeholder-field-name')), 'World');
      await tester.tap(find.byKey(const Key('placeholder-submit')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['Hello, World!']);
    });

    testWidgets('取消填表则不粘贴', (tester) async {
      final ctx = await pumpOverlay(tester, content: 'echo {value}');

      await pressEnter(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(ctx.pasted, isEmpty);
      expect(find.byKey(const Key('placeholder-form')), findsNothing);
    });

    testWidgets('无占位符片段不弹填表框', (tester) async {
      final ctx = await pumpOverlay(tester, content: 'plain text');

      await pressEnter(tester);

      expect(find.byKey(const Key('placeholder-form')), findsNothing);
      expect(ctx.pasted, ['plain text']);
    });

    testWidgets('字面 {{ }} 不触发填表且渲染为单大括号', (tester) async {
      final ctx = await pumpOverlay(tester, content: 'if (x) {{ y(); }}');

      await pressEnter(tester);

      expect(find.byKey(const Key('placeholder-form')), findsNothing);
      expect(ctx.pasted, ['if (x) { y(); }']);
    });

    testWidgets('渲染出多行内容且目标为终端时仍触发终端确认', (tester) async {
      final ctx = await pumpOverlay(tester,
          content: 'echo {a}\necho done', targetProcess: 'cmd.exe');

      await pressEnter(tester);
      await tester.enterText(
          find.byKey(const Key('placeholder-field-a')), 'hi');
      await tester.tap(find.byKey(const Key('placeholder-submit')));
      await tester.pumpAndSettle();

      // 填表后进入终端多行确认
      expect(find.byKey(const Key('terminal-paste-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('terminal-paste-proceed')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['echo hi\necho done']);
    });
  });
}
