import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/utils/search_query.dart';

import 'helpers/mocks.dart';

void main() {
  group('parseSearchQuery', () {
    test('分离 #tag 与自由文本', () {
      final q = parseSearchQuery('#git push origin');
      expect(q.tags, ['git']);
      expect(q.text, 'push origin');
    });

    test('多个 #tag', () {
      final q = parseSearchQuery('#git #wip fix');
      expect(q.tags, ['git', 'wip']);
      expect(q.text, 'fix');
    });

    test('无 tag 纯文本', () {
      final q = parseSearchQuery('hello world');
      expect(q.tags, isEmpty);
      expect(q.text, 'hello world');
    });

    test('孤立 # 忽略', () {
      final q = parseSearchQuery('# foo');
      expect(q.tags, isEmpty);
      expect(q.text, 'foo');
    });

    test('空查询', () {
      expect(parseSearchQuery('   ').isEmpty, isTrue);
    });
  });

  group('matchesTags', () {
    test('全部标签约束子串命中', () {
      expect(matchesTags(['git', 'deploy'], ['git']), isTrue);
      expect(matchesTags(['git'], ['gi']), isTrue); // 子串
      expect(matchesTags(['git'], ['git', 'wip']), isFalse); // 缺 wip
    });

    test('无标签约束恒真', () {
      expect(matchesTags([], []), isTrue);
    });
  });

  group('highlightRanges', () {
    test('单次命中', () {
      expect(highlightRanges('git push', 'push'), [(4, 8)]);
    });

    test('多次命中', () {
      expect(highlightRanges('aba', 'a'), [(0, 1), (2, 3)]);
    });

    test('大小写不敏感', () {
      expect(highlightRanges('Git', 'git'), [(0, 3)]);
    });

    test('无命中返回空', () {
      expect(highlightRanges('abc', 'x'), isEmpty);
      expect(highlightRanges('abc', ''), isEmpty);
    });
  });

  group('Provider #tag 过滤', () {
    Snippet snip(String id, String name, List<String> tags) =>
        Snippet(id: id, name: name, content: 'c-$id', tags: tags);

    test('#tag 过滤到含该标签的片段', () async {
      final storage = MockStorageService();
      await storage.saveSnippets([
        snip('a', 'deploy', ['git', 'ops']),
        snip('b', 'note', ['personal']),
        snip('c', 'push', ['git']),
      ]);
      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();

      provider.setSearchQuery('#git');

      expect(provider.filteredSnippets.map((s) => s.id).toSet(), {'a', 'c'});
    });

    test('#tag 与关键词组合', () async {
      final storage = MockStorageService();
      await storage.saveSnippets([
        snip('a', 'deploy prod', ['git']),
        snip('c', 'push origin', ['git']),
      ]);
      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();

      provider.setSearchQuery('#git push');

      expect(provider.filteredSnippets.map((s) => s.id), ['c']);
    });

    test('searchText 剥离 #tag 供高亮', () async {
      final storage = MockStorageService();
      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();

      provider.setSearchQuery('#git push');

      expect(provider.searchText, 'push');
    });
  });
}
