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
    // 模拟系统剪贴板
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': 'CLIP'};
      }
      return null;
    });
  });

  Future<({SnippetProvider provider, List<String> pasted})> pumpOverlay(
    WidgetTester tester,
    String content,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage.saveSnippets([Snippet(id: 't', name: 'tpl', content: content, isTemplate: true)]);

    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (text) async {
        pasted.add(text);
        return PasteOutcome.pasted;
      },
      targetProcessName: () => null,
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

  group('内置变量在搜索窗粘贴路径', () {
    testWidgets('纯内置变量不弹填表，clipboard 自动注入', (tester) async {
      final ctx = await pumpOverlay(tester, '内容：{clipboard}');

      await pressEnter(tester);

      expect(find.byKey(const Key('placeholder-form')), findsNothing);
      expect(ctx.pasted, ['内容：CLIP']);
    });

    testWidgets('自定义占位符弹表且预填默认值，内置变量仍自动求值', (tester) async {
      final ctx = await pumpOverlay(tester, '{branch:main} @ {clipboard}');

      await pressEnter(tester);
      // 默认值已预填
      expect(find.widgetWithText(TextField, 'main'), findsOneWidget);

      await tester.tap(find.byKey(const Key('placeholder-submit')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['main @ CLIP']);
    });

    testWidgets('留空使用默认值', (tester) async {
      final ctx = await pumpOverlay(tester, 'branch {name:dev}');

      await pressEnter(tester);
      await tester.enterText(
          find.byKey(const Key('placeholder-field-name')), '');
      await tester.tap(find.byKey(const Key('placeholder-submit')));
      await tester.pumpAndSettle();

      expect(ctx.pasted, ['branch dev']);
    });
  });
}
