import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/snippet_stats.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  final now = DateTime(2026, 7, 11, 12);

  group('SnippetStats frecency', () {
    test('单次使用：刚用过得分 1，7 天前得分约 0.5（半衰期）', () {
      final fresh = SnippetStats.zero.used(now);
      final weekOld = SnippetStats.zero.used(now.subtract(const Duration(days: 7)));

      expect(fresh.frecencyScore(now), closeTo(1.0, 0.01));
      expect(weekOld.frecencyScore(now), closeTo(0.5, 0.01));
    });

    test('近期低频 > 远古高频', () {
      // 远古高频：100 次使用，全部在 60 天前
      var ancient = SnippetStats.zero;
      final longAgo = now.subtract(const Duration(days: 60));
      for (var i = 0; i < 100; i++) {
        ancient = ancient.used(longAgo);
      }
      // 近期低频：昨天和今天各用一次
      var recent = SnippetStats.zero;
      recent = recent.used(now.subtract(const Duration(days: 1)));
      recent = recent.used(now);

      expect(recent.frecencyScore(now), greaterThan(ancient.frecencyScore(now)));
    });

    test('recentUses 只保留最近 10 次', () {
      var stats = SnippetStats.zero;
      for (var i = 15; i > 0; i--) {
        stats = stats.used(now.subtract(Duration(days: i)));
      }

      expect(stats.recentUses.length, 10);
      expect(stats.frequency, 15);
      // 保留的是最近的 10 次（1..10 天前），最老的 5 次被截断
      expect(stats.recentUses.first, now.subtract(const Duration(days: 10)));
      expect(stats.recentUses.last, now.subtract(const Duration(days: 1)));
    });

    test('从未使用过 frecency 为 0', () {
      expect(SnippetStats.zero.frecencyScore(now), 0);
    });

    test('旧格式 stats.json（无 recentUses）无损迁移', () {
      // Arrange — v0.1.6 及以前的格式
      final legacy = {
        'frequency': 5,
        'lastUsedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      };

      // Act
      final stats = SnippetStats.fromJson(legacy);

      // Assert — lastUsedAt 合成为一条使用记录，仍参与 frecency
      expect(stats.frequency, 5);
      expect(stats.recentUses, hasLength(1));
      expect(stats.frecencyScore(now), greaterThan(0));
    });

    test('toJson/fromJson 往返保留 recentUses', () {
      var stats = SnippetStats.zero.used(now.subtract(const Duration(days: 2)));
      stats = stats.used(now);

      final restored = SnippetStats.fromJson(stats.toJson());

      expect(restored.frequency, 2);
      expect(restored.recentUses, stats.recentUses);
      expect(restored.lastUsedAt, stats.lastUsedAt);
    });
  });

  group('SnippetProvider frecency 排序', () {
    Snippet snippet(String id, String name) =>
        Snippet(id: id, name: name, content: 'content-$id');

    test('近期使用的片段排在远古高频片段前面', () async {
      // Arrange
      final storage = MockStorageService();
      await storage.saveSnippets([snippet('old', '远古高频'), snippet('new', '近期低频')]);

      var ancient = SnippetStats.zero;
      final longAgo = now.subtract(const Duration(days: 90));
      for (var i = 0; i < 50; i++) {
        ancient = ancient.used(longAgo);
      }
      storage.seedStats({
        'old': ancient,
        'new': SnippetStats.zero.used(now.subtract(const Duration(hours: 1))),
      });

      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );

      // Act
      await provider.loadSnippets();

      // Assert
      expect(provider.filteredSnippets.first.id, 'new');
    });

    test('都未使用过时按名称排序（同分退避）', () async {
      final storage = MockStorageService();
      await storage.saveSnippets([snippet('b', 'bravo'), snippet('a', 'alpha')]);

      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );

      await provider.loadSnippets();

      expect(provider.filteredSnippets.map((s) => s.name).toList(),
          ['alpha', 'bravo']);
    });
  });
}
