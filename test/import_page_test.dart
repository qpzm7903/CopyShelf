import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/import_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/importers/importer.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

/// 固定候选的测试 importer
class FakeImporter extends Importer {
  final List<ImportCandidate> candidates;
  FakeImporter(this.candidates);

  @override
  String get displayName => 'Fake';

  @override
  Future<List<ImportCandidate>> discover() async => candidates;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SnippetProvider> pump(
    WidgetTester tester,
    List<ImportCandidate> candidates, {
    List<Snippet> existing = const [],
  }) async {
    final storage = MockStorageService();
    if (existing.isNotEmpty) await storage.saveSnippets(existing);
    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await provider.loadSnippets();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: ImportPage(importer: FakeImporter(candidates))),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('导入页', () {
    testWidgets('候选默认全选，确认后批量入库', (tester) async {
      final provider = await pump(tester, const [
        ImportCandidate(name: 'git status', content: 'git status'),
        ImportCandidate(name: 'npm i', content: 'npm install'),
      ]);

      expect(find.byKey(const Key('import-item-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-confirm')));
      await tester.pumpAndSettle();

      expect(provider.snippets.map((s) => s.content),
          containsAll(['git status', 'npm install']));
    });

    testWidgets('取消勾选后只导入选中项', (tester) async {
      final provider = await pump(tester, const [
        ImportCandidate(name: 'a', content: 'cmd-a'),
        ImportCandidate(name: 'b', content: 'cmd-b'),
      ]);

      await tester.tap(find.byKey(const Key('import-item-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-confirm')));
      await tester.pumpAndSettle();

      expect(provider.snippets.map((s) => s.content), ['cmd-a']);
    });

    testWidgets('已存在的候选被过滤', (tester) async {
      await pump(
        tester,
        const [
          ImportCandidate(name: 'a', content: 'existing'),
          ImportCandidate(name: 'b', content: 'new-one'),
        ],
        existing: [Snippet(id: 'x', name: 'x', content: 'existing')],
      );

      expect(find.byKey(const Key('import-item-1')), findsNothing);
      expect(find.text('new-one'), findsOneWidget);
    });

    testWidgets('全部候选都已存在时显示空状态', (tester) async {
      await pump(
        tester,
        const [ImportCandidate(name: 'a', content: 'dup')],
        existing: [Snippet(id: 'x', name: 'x', content: 'dup')],
      );

      expect(find.byKey(const Key('import-empty')), findsOneWidget);
    });

    testWidgets('含大括号候选入库时被转义', (tester) async {
      final provider = await pump(tester, const [
        ImportCandidate(name: 'p', content: 'ls | % { \$_.Name }'),
      ]);

      await tester.tap(find.byKey(const Key('import-confirm')));
      await tester.pumpAndSettle();

      expect(provider.snippets.single.content, contains('{{'));
    });
  });
}
