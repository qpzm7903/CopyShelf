import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/models/snippet_stats.dart';

void main() {
  group('Snippet model', () {
    test('toJson / fromJson roundtrip', () {
      final snippet = Snippet(
        id: 'test-id',
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改上次提交',
        tags: ['git', '常用'],
        createdAt: DateTime(2026, 7, 1, 10, 0, 0),
      );

      final json = snippet.toJson();
      final restored = Snippet.fromJson(json);

      expect(restored.id, snippet.id);
      expect(restored.name, snippet.name);
      expect(restored.content, snippet.content);
      expect(restored.description, snippet.description);
      expect(restored.tags, snippet.tags);
      expect(restored.createdAt, snippet.createdAt);
    });

    test('toJson does not contain usage stats fields (ADR-0001)', () {
      final snippet = Snippet(id: 'id', name: 'n', content: 'c');
      final json = snippet.toJson();

      expect(json.containsKey('frequency'), isFalse);
      expect(json.containsKey('lastUsedAt'), isFalse);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test-id',
        'name': 'test',
        'content': 'test content',
      };

      final snippet = Snippet.fromJson(json);
      expect(snippet.id, 'test-id');
      expect(snippet.name, 'test');
      expect(snippet.content, 'test content');
      expect(snippet.description, '');
      expect(snippet.tags, []);
      expect(snippet.createdAt, isNotNull);
    });

    test('fromJson ignores legacy stats fields from old data files', () {
      final json = {
        'id': 'test-id',
        'name': 'test',
        'content': 'c',
        'frequency': 42,
        'lastUsedAt': '2026-07-04T12:00:00Z',
      };

      final snippet = Snippet.fromJson(json);
      expect(snippet.toJson().containsKey('frequency'), isFalse);
    });

    test('copyWith creates a copy with overridden fields', () {
      final snippet = Snippet(
        id: 'test-id',
        name: 'git amend',
        content: 'git commit --amend --no-edit',
      );

      final copy = snippet.copyWith(
        name: 'git commit --amend',
        tags: ['git'],
      );

      expect(copy.id, snippet.id);
      expect(copy.name, 'git commit --amend');
      expect(copy.content, snippet.content);
      expect(copy.tags, ['git']);
      // 原对象未被修改
      expect(snippet.name, 'git amend');
      expect(snippet.tags, []);
    });

    test('tags default to empty list', () {
      final snippet = Snippet(id: 'id', name: 'n', content: 'c');
      expect(snippet.tags, []);
    });
  });

  group('SnippetStats model', () {
    test('toJson / fromJson roundtrip', () {
      final stats = SnippetStats(
        frequency: 5,
        lastUsedAt: DateTime(2026, 7, 4, 12, 0, 0),
      );

      final restored = SnippetStats.fromJson(stats.toJson());
      expect(restored.frequency, 5);
      expect(restored.lastUsedAt, DateTime(2026, 7, 4, 12, 0, 0));
    });

    test('zero stats have frequency 0 and epoch lastUsedAt', () {
      expect(SnippetStats.zero.frequency, 0);
      expect(SnippetStats.zero.lastUsedAt,
          DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('used() returns a NEW instance with incremented frequency', () {
      final stats = SnippetStats(
        frequency: 2,
        lastUsedAt: DateTime(2026, 7, 1),
      );
      final at = DateTime(2026, 7, 4);

      final next = stats.used(at);

      expect(next.frequency, 3);
      expect(next.lastUsedAt, at);
      // 不可变：原对象保持不变
      expect(stats.frequency, 2);
      expect(stats.lastUsedAt, DateTime(2026, 7, 1));
      expect(identical(stats, next), isFalse);
    });
  });
}
