import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/tag_filter.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SnippetProvider> pumpOverlay(
    WidgetTester tester,
    List<Snippet> snippets,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = MockStorageService();
    await storage.saveSnippets(snippets);

    final provider = SnippetProvider(
      storage: storage,
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

  Snippet snip(String id, {List<String>? tags}) =>
      Snippet(id: id, name: id, content: 'content-$id', tags: tags);

  group('标签栏显隐', () {
    testWidgets('片段库为空时不渲染标签栏', (tester) async {
      await pumpOverlay(tester, []);

      expect(find.byKey(const Key('tag-sidebar')), findsNothing);
    });

    testWidgets('库非空但没有标签：标签栏常驻并显示引导文案', (tester) async {
      await pumpOverlay(tester, [snip('a'), snip('b')]);

      expect(find.byKey(const Key('tag-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('tag-item-all')), findsOneWidget);
      expect(find.byKey(const Key('tag-rail-empty-hint')), findsOneWidget);
      // 全库都无标签时「无标签」与「全部」等价，不显示
      expect(find.byKey(const Key('tag-item-untagged')), findsNothing);
    });

    testWidgets('有标签时渲染：全部 + 无标签 + 各标签', (tester) async {
      await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('b', tags: ['docker']),
        snip('c'),
      ]);

      expect(find.byKey(const Key('tag-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('tag-item-all')), findsOneWidget);
      expect(find.byKey(const Key('tag-item-untagged')), findsOneWidget);
      expect(find.byKey(const Key('tag-item-git')), findsOneWidget);
      expect(find.byKey(const Key('tag-item-docker')), findsOneWidget);
      expect(find.byKey(const Key('tag-rail-empty-hint')), findsNothing);
    });

    testWidgets('全部片段都有标签时不显示「无标签」项', (tester) async {
      await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('b', tags: ['docker']),
      ]);

      expect(find.byKey(const Key('tag-item-untagged')), findsNothing);
    });
  });

  group('标签栏过滤', () {
    testWidgets('点击标签项：列表只剩该标签片段', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('b', tags: ['docker']),
        snip('c'),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();

      expect(provider.tagFilter, const TagFilter.tag('git'));
      expect(provider.filteredSnippets.map((s) => s.id), ['a']);
    });

    testWidgets('点击「无标签」：只显示无标签片段', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-untagged')));
      await tester.pumpAndSettle();

      expect(provider.filteredSnippets.map((s) => s.id), ['c']);
    });

    testWidgets('点击「全部」恢复完整列表', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);
      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tag-item-all')));
      await tester.pumpAndSettle();

      expect(provider.tagFilter, const TagFilter.all());
      expect(provider.filteredSnippets.length, 2);
    });

    testWidgets('标签过滤下输入关键词：两者叠加过滤', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('push', tags: ['git']),
        snip('pull', tags: ['git']),
        snip('push-image', tags: ['docker']),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'push');
      await tester.pumpAndSettle();

      expect(provider.filteredSnippets.map((s) => s.id), ['push']);
    });

    testWidgets('标签下无匹配片段时提示「该标签下没有匹配的片段」', (tester) async {
      await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('b', tags: ['docker']),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('该标签下没有匹配的片段'), findsOneWidget);
    });
  });

  group('搜索栏过滤胶囊', () {
    testWidgets('未过滤时不显示胶囊', (tester) async {
      await pumpOverlay(tester, [snip('a', tags: ['git'])]);

      expect(find.byKey(const Key('active-tag-chip')), findsNothing);
    });

    testWidgets('选中标签后搜索栏出现「# 标签名」胶囊', (tester) async {
      await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-tag-chip')), findsOneWidget);
      expect(find.text('# git'), findsOneWidget);
    });

    testWidgets('选中「无标签」胶囊文案为「无标签」', (tester) async {
      await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);

      await tester.tap(find.byKey(const Key('tag-item-untagged')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-tag-chip')), findsOneWidget);
      expect(find.text('无标签'), findsNWidgets(2)); // 侧栏项 + 胶囊
    });

    testWidgets('点胶囊的 × 清除过滤回到全部', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);
      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('active-tag-chip-clear')));
      await tester.pumpAndSettle();

      expect(provider.tagFilter, const TagFilter.all());
      expect(find.byKey(const Key('active-tag-chip')), findsNothing);
      expect(provider.filteredSnippets.length, 2);
    });

    testWidgets('空输入框按 Backspace 清除标签过滤', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);
      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(provider.tagFilter, const TagFilter.all());
    });

    testWidgets('输入框有内容时 Backspace 正常删字，不清除过滤', (tester) async {
      final provider = await pumpOverlay(tester, [
        snip('a', tags: ['git']),
        snip('c'),
      ]);
      await tester.tap(find.byKey(const Key('tag-item-git')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(provider.tagFilter, const TagFilter.tag('git'));
      expect(provider.searchQuery, 'a');
    });
  });
}
