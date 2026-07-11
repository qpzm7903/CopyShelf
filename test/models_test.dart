import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';

void main() {
  group('Snippet model', () {
    test('toJson / fromJson roundtrip', () {
      final snippet = Snippet(
        id: 'test-id',
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改上次提交',
        tags: ['git', '常用'],
        frequency: 5,
        lastUsedAt: DateTime(2026, 7, 4, 12, 0, 0),
        createdAt: DateTime(2026, 7, 1, 10, 0, 0),
      );

      final json = snippet.toJson();
      final restored = Snippet.fromJson(json);

      expect(restored.id, snippet.id);
      expect(restored.name, snippet.name);
      expect(restored.content, snippet.content);
      expect(restored.description, snippet.description);
      expect(restored.tags, snippet.tags);
      expect(restored.frequency, snippet.frequency);
      expect(restored.lastUsedAt, snippet.lastUsedAt);
      expect(restored.createdAt, snippet.createdAt);
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
      expect(snippet.frequency, 0);
      expect(snippet.lastUsedAt, isNotNull);
      expect(snippet.createdAt, isNotNull);
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
      expect(copy.frequency, snippet.frequency);
    });

    test('tags default to empty list', () {
      final snippet = Snippet(id: 'id', name: 'n', content: 'c');
      expect(snippet.tags, []);
    });

    test('lastUsedAt and createdAt default to now', () {
      final before = DateTime.now();
      final snippet = Snippet(id: 'id', name: 'n', content: 'c');
      final after = DateTime.now();

      expect(snippet.lastUsedAt.isAfter(before) || snippet.lastUsedAt == before, isTrue);
      expect(snippet.lastUsedAt.isBefore(after) || snippet.lastUsedAt == after, isTrue);
      expect(snippet.createdAt.isAfter(before) || snippet.createdAt == before, isTrue);
      expect(snippet.createdAt.isBefore(after) || snippet.createdAt == after, isTrue);
    });
  });
}
