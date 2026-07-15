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
            return <String, dynamic>{'text': 'git status'};
          }
          return null;
        });
  });

  Future<SnippetProvider> pumpOverlay(WidgetTester tester) async {
    final provider = SnippetProvider(
      storage: MockStorageService(),
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await provider.loadSnippets();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SearchOverlay())),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets(
    'quick create prefills name from query and content from clipboard',
    (tester) async {
      final provider = await pumpOverlay(tester);
      await tester.enterText(find.byType(TextField).first, 'Git status');

      await tester.tap(find.byKey(const Key('quick-create-button')));
      await tester.pumpAndSettle();

      final name = tester.widget<TextField>(
        find.byKey(const Key('snippet-name-field')),
      );
      final content = tester.widget<TextField>(
        find.byKey(const Key('snippet-content-field')),
      );
      expect(name.controller!.text, 'Git status');
      expect(content.controller!.text, 'git status');
      expect(provider.isSnippetEditorOpen, isTrue);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(provider.snippets, hasLength(1));
      expect(provider.snippets.single.name, 'Git status');
      expect(provider.snippets.single.content, 'git status');
      expect(provider.isSnippetEditorOpen, isFalse);
    },
  );

  testWidgets('Ctrl+N opens the same quick-create workflow', (tester) async {
    await pumpOverlay(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snippet-content-field')), findsOneWidget);
  });
}
