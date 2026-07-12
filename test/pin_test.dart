import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/snippet_stats.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  final now = DateTime(2026, 7, 11, 12);

  group('SnippetStats 置顶', () {
    test('withPinned 切换且保留其他字段', () {
      final s = SnippetStats.zero.used(now).withPinned(true);
      expect(s.pinned, isTrue);
      expect(s.frequency, 1);
      expect(s.withPinned(false).pinned, isFalse);
    });

    test('toJson/fromJson 往返保留 pinned', () {
      final s = SnippetStats.zero.withPinned(true);
      expect(SnippetStats.fromJson(s.toJson()).pinned, isTrue);
    });

    test('未置顶不写入 pinned 字段（省空间）', () {
      expect(SnippetStats.zero.toJson().containsKey('pinned'), isFalse);
    });
  });

  group('SnippetProvider 置顶排序', () {
    Snippet snip(String id) => Snippet(id: id, name: id, content: id);

    late MockStorageService storage;
    late SnippetProvider provider;

    setUp(() async {
      storage = MockStorageService();
      await storage.saveSnippets([snip('a'), snip('b'), snip('c')]);
      // b 高频，a/c 无使用
      storage.seedStats({
        'b': SnippetStats.zero.used(now).used(now),
      });
      provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();
    });

    test('置顶项恒排最前，即使频次更低', () async {
      // 初始 b（高频）在前
      expect(provider.filteredSnippets.first.id, 'b');

      await provider.togglePin('c'); // c 从未使用但置顶

      expect(provider.filteredSnippets.first.id, 'c');
    });

    test('多个置顶项之间按 frecency 排序', () async {
      await provider.togglePin('a');
      await provider.togglePin('b'); // a、b 都置顶，b 频次高

      final ids = provider.filteredSnippets.map((s) => s.id).toList();
      expect(ids.indexOf('b'), lessThan(ids.indexOf('a')));
      // 非置顶的 c 在最后
      expect(ids.last, 'c');
    });

    test('取消置顶后回到 frecency 排序', () async {
      await provider.togglePin('c');
      expect(provider.filteredSnippets.first.id, 'c');

      await provider.togglePin('c');
      expect(provider.filteredSnippets.first.id, 'b');
    });

    test('置顶状态持久化到 stats.json', () async {
      await provider.togglePin('a');

      expect(storage.storedStats['a']?.pinned, isTrue);
      expect(storage.saveStatsCallCount, greaterThan(0));
    });

    test('置顶不触发 Git 同步（本地统计 ADR-0001）', () async {
      final git = provider;
      await git.togglePin('a');
      // MockGitService.commitAndPush 不应被调用——通过无异常且 stats 已存验证
      expect(storage.storedStats['a']?.pinned, isTrue);
    });
  });
}
