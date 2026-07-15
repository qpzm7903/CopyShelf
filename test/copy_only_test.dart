import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': 'CLIP'};
          }
          return null;
        });
  });

  Future<({SnippetProvider provider, List<String> copied, List<String> pasted})>
  pumpOverlay(
    WidgetTester tester,
    Snippet snippet, {
    String? targetProcess,
  }) async {
    final copied = <String>[];
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage.saveSnippets([snippet]);
    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      copy: (text) async {
        copied.add(text);
        return true;
      },
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
    return (provider: provider, copied: copied, pasted: pasted);
  }

  Future<void> pressCtrlEnter(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+Enter copies selected snippet without pasting', (
    tester,
  ) async {
    final ctx = await pumpOverlay(
      tester,
      Snippet(id: 'plain', name: 'plain', content: 'copy me'),
    );

    await pressCtrlEnter(tester);

    expect(ctx.copied, ['copy me']);
    expect(ctx.pasted, isEmpty);
    expect(ctx.provider.statsFor('plain').frequency, 1);
    expect(find.textContaining('已复制'), findsOneWidget);
  });

  testWidgets('copy resolves templates and skips terminal multiline guard', (
    tester,
  ) async {
    final ctx = await pumpOverlay(
      tester,
      Snippet(
        id: 'template',
        name: 'template',
        content: '{name:Alice}\n{clipboard}',
        isTemplate: true,
      ),
      targetProcess: 'cmd.exe',
    );

    await pressCtrlEnter(tester);
    expect(find.byKey(const Key('placeholder-form')), findsOneWidget);
    await tester.tap(find.byKey(const Key('placeholder-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('terminal-paste-confirm')), findsNothing);
    expect(ctx.copied, ['Alice\nCLIP']);
    expect(ctx.pasted, isEmpty);
  });

  testWidgets('footer advertises copy shortcut', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 500);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpOverlay(
      tester,
      Snippet(id: 'plain', name: 'plain', content: 'copy me'),
    );

    expect(find.byKey(const Key('copy-shortcut-hint')), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
  });
}
