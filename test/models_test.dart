import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/command.dart';

void main() {
  group('Command model', () {
    test('toJson / fromJson roundtrip', () {
      final command = Command(
        id: 'test-id',
        name: 'git amend',
        content: 'git commit --amend --no-edit',
        description: '快速修改上次提交',
        tags: ['git', '常用'],
        frequency: 5,
        lastUsedAt: DateTime(2026, 7, 4, 12, 0, 0),
        createdAt: DateTime(2026, 7, 1, 10, 0, 0),
      );

      final json = command.toJson();
      final restored = Command.fromJson(json);

      expect(restored.id, command.id);
      expect(restored.name, command.name);
      expect(restored.content, command.content);
      expect(restored.description, command.description);
      expect(restored.tags, command.tags);
      expect(restored.frequency, command.frequency);
      expect(restored.lastUsedAt, command.lastUsedAt);
      expect(restored.createdAt, command.createdAt);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test-id',
        'name': 'test',
        'content': 'test content',
      };

      final command = Command.fromJson(json);
      expect(command.id, 'test-id');
      expect(command.name, 'test');
      expect(command.content, 'test content');
      expect(command.description, '');
      expect(command.tags, []);
      expect(command.frequency, 0);
      expect(command.lastUsedAt, isNotNull);
      expect(command.createdAt, isNotNull);
    });

    test('copyWith creates a copy with overridden fields', () {
      final command = Command(
        id: 'test-id',
        name: 'git amend',
        content: 'git commit --amend --no-edit',
      );

      final copy = command.copyWith(
        name: 'git commit --amend',
        tags: ['git'],
      );

      expect(copy.id, command.id);
      expect(copy.name, 'git commit --amend');
      expect(copy.content, command.content);
      expect(copy.tags, ['git']);
      expect(copy.frequency, command.frequency);
    });

    test('tags default to empty list', () {
      final command = Command(id: 'id', name: 'n', content: 'c');
      expect(command.tags, []);
    });

    test('lastUsedAt and createdAt default to now', () {
      final before = DateTime.now();
      final command = Command(id: 'id', name: 'n', content: 'c');
      final after = DateTime.now();

      expect(command.lastUsedAt.isAfter(before) || command.lastUsedAt == before, isTrue);
      expect(command.lastUsedAt.isBefore(after) || command.lastUsedAt == after, isTrue);
      expect(command.createdAt.isAfter(before) || command.createdAt == before, isTrue);
      expect(command.createdAt.isBefore(after) || command.createdAt == after, isTrue);
    });
  });
}
