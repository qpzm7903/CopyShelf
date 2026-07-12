import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/snippet_editor_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String json(String id, String name, String content) =>
      '[{"id":"$id","name":"$name","content":"$content"}]';

  Future<SnippetProvider> pumpEditor(WidgetTester tester) async {
    final storage = MockStorageService();
    final git = MockGitService();
    git.commitContents['c1'] = json('a', 'cmd', 'old-content');
    git.commitContents['c2'] = json('a', 'cmd', 'current');
    await storage.saveSnippets([Snippet(id: 'a', name: 'cmd', content: 'current')]);

    final provider = SnippetProvider(
      storage: storage,
      git: git,
      paste: (_) async => PasteOutcome.pasted,
    );
    await provider.loadSnippets();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: SnippetEditorPage(snippet: provider.snippets.first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('编辑页历史版本 UI', () {
    testWidgets('新建模式无历史按钮', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: SnippetProvider(
            storage: MockStorageService(),
            git: MockGitService(),
            paste: (_) async => PasteOutcome.pasted,
          ),
          child: const MaterialApp(home: SnippetEditorPage()),
        ),
      );
      expect(find.byKey(const Key('snippet-history-button')), findsNothing);
    });

    testWidgets('编辑模式点历史按钮弹出历史列表', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.byKey(const Key('snippet-history-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('snippet-history-dialog')), findsOneWidget);
      expect(find.byKey(const Key('history-item-0')), findsOneWidget);
      // 历史含 old-content 版本
      expect(find.textContaining('old-content'), findsOneWidget);
    });

    testWidgets('选中历史版本把内容填回编辑器', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const Key('snippet-history-button')));
      await tester.pumpAndSettle();

      // 点 old-content 那一条（c1 最旧，倒序后是 item-1）
      await tester.tap(find.textContaining('old-content'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'old-content'), findsOneWidget);
      expect(find.text('已载入历史版本，点「保存」确认恢复'), findsOneWidget);
    });
  });
}
