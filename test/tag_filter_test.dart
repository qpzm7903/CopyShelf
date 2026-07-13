import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/tag_filter.dart';
import 'package:copyshelf/providers/snippet_provider.dart';

import 'helpers/mocks.dart';

void main() {
  group('TagFilter.matches', () {
    test('全部：任何片段都命中', () {
      const filter = TagFilter.all();
      expect(filter.matches([]), isTrue);
      expect(filter.matches(['git']), isTrue);
    });

    test('无标签：只命中空标签片段', () {
      const filter = TagFilter.untagged();
      expect(filter.matches([]), isTrue);
      expect(filter.matches(['git']), isFalse);
    });

    test('指定标签：不区分大小写的精确匹配', () {
      const filter = TagFilter.tag('Git');
      expect(filter.matches(['git', 'wip']), isTrue);
      expect(filter.matches(['GIT']), isTrue);
      expect(filter.matches(['wip']), isFalse);
    });

    test('指定标签是精确匹配，不是子串匹配', () {
      const filter = TagFilter.tag('git');
      expect(filter.matches(['github']), isFalse);
    });

    test('相等性：同类型同标签相等，可用于选中态比较', () {
      expect(const TagFilter.all(), const TagFilter.all());
      expect(const TagFilter.untagged(), const TagFilter.untagged());
      expect(const TagFilter.tag('git'), const TagFilter.tag('git'));
      expect(const TagFilter.all() == const TagFilter.untagged(), isFalse);
      expect(
          const TagFilter.tag('git') == const TagFilter.tag('wip'), isFalse);
    });
  });

  group('SnippetProvider 标签过滤', () {
    Snippet snip(String id, {List<String>? tags}) =>
        Snippet(id: id, name: id, content: 'content-$id', tags: tags);

    late MockStorageService storage;
    late SnippetProvider provider;

    Future<void> seed(List<Snippet> snippets) async {
      storage = MockStorageService();
      await storage.saveSnippets(snippets);
      provider = SnippetProvider(storage: storage, git: MockGitService());
      await provider.loadSnippets();
    }

    test('allTags 去重（不区分大小写）、按字典序、保留首次出现的写法', () async {
      await seed([
        snip('a', tags: ['Docker', 'k8s']),
        snip('b', tags: ['docker', 'CodeHub']),
        snip('c'),
      ]);

      expect(provider.allTags, ['CodeHub', 'Docker', 'k8s']);
    });

    test('hasUntaggedSnippets 反映库中是否有无标签片段', () async {
      await seed([snip('a', tags: ['git'])]);
      expect(provider.hasUntaggedSnippets, isFalse);

      await seed([snip('a', tags: ['git']), snip('b')]);
      expect(provider.hasUntaggedSnippets, isTrue);
    });

    test('setTagFilter 指定标签：只保留该标签片段', () async {
      await seed([
        snip('a', tags: ['git']),
        snip('b', tags: ['docker']),
        snip('c'),
      ]);

      provider.setTagFilter(const TagFilter.tag('git'));

      expect(provider.filteredSnippets.map((s) => s.id), ['a']);
      expect(provider.tagFilter, const TagFilter.tag('git'));
    });

    test('setTagFilter 无标签：只保留无标签片段', () async {
      await seed([
        snip('a', tags: ['git']),
        snip('b'),
      ]);

      provider.setTagFilter(const TagFilter.untagged());

      expect(provider.filteredSnippets.map((s) => s.id), ['b']);
    });

    test('标签过滤与关键词搜索叠加（AND）', () async {
      await seed([
        snip('push', tags: ['git']),
        snip('pull', tags: ['git']),
        snip('push-image', tags: ['docker']),
      ]);

      provider.setTagFilter(const TagFilter.tag('git'));
      provider.setSearchQuery('push');

      expect(provider.filteredSnippets.map((s) => s.id), ['push']);
    });

    test('切回全部恢复完整列表', () async {
      await seed([
        snip('a', tags: ['git']),
        snip('b'),
      ]);
      provider.setTagFilter(const TagFilter.tag('git'));

      provider.setTagFilter(const TagFilter.all());

      expect(provider.filteredSnippets.length, 2);
    });

    test('showSearch 重置标签过滤为全部（与清空搜索词一致）', () async {
      await seed([
        snip('a', tags: ['git']),
        snip('b'),
      ]);
      provider.setTagFilter(const TagFilter.tag('git'));

      provider.showSearch();

      expect(provider.tagFilter, const TagFilter.all());
      expect(provider.filteredSnippets.length, 2);
    });
  });
}
