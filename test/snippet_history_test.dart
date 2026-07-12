import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  late MockStorageService storage;
  late MockGitService git;

  SnippetProvider build() => SnippetProvider(
        storage: storage,
        git: git,
        paste: (_) async => PasteOutcome.pasted,
      );

  setUp(() {
    storage = MockStorageService();
    git = MockGitService();
  });

  String snippetsJson(String id, String name, String content) =>
      '[{"id":"$id","name":"$name","content":"$content"}]';

  group('片段历史', () {
    test('抽取某片段跨提交的历史版本，最新在前', () async {
      git.commitContents['c1'] = snippetsJson('a', 'cmd', 'v1');
      git.commitContents['c2'] = snippetsJson('a', 'cmd', 'v2');
      git.commitContents['c3'] = snippetsJson('a', 'cmd', 'v3');
      await storage.saveSnippets(
          [Snippet(id: 'a', name: 'cmd', content: 'v3')]);
      final provider = build();
      await provider.loadSnippets();

      final history = await provider.snippetHistory('a');

      expect(history.map((v) => v.snippet.content).toList(), ['v3', 'v2', 'v1']);
    });

    test('连续相同内容的版本去重', () async {
      git.commitContents['c1'] = snippetsJson('a', 'cmd', 'same');
      git.commitContents['c2'] = snippetsJson('a', 'cmd', 'same');
      git.commitContents['c3'] = snippetsJson('a', 'cmd', 'different');
      final provider = build();

      final history = await provider.snippetHistory('a');

      expect(history.map((v) => v.snippet.content).toList(),
          ['different', 'same']);
    });

    test('该片段不在某提交中时跳过该版本', () async {
      git.commitContents['c1'] = snippetsJson('other', 'x', 'y');
      git.commitContents['c2'] = snippetsJson('a', 'cmd', 'v1');
      final provider = build();

      final history = await provider.snippetHistory('a');

      expect(history, hasLength(1));
      expect(history.first.snippet.content, 'v1');
    });

    test('恢复片段到历史版本：只改该条并触发同步', () async {
      storage.hasRemote = true;
      await storage.saveSnippets([
        Snippet(id: 'a', name: 'cmd', content: 'current'),
        Snippet(id: 'b', name: 'other', content: 'untouched'),
      ]);
      final provider = build();
      await provider.loadSnippets();

      await provider.restoreSnippet(
          'a', Snippet(id: 'a', name: 'cmd-old', content: 'old-version'));

      final a = provider.snippets.firstWhere((s) => s.id == 'a');
      final b = provider.snippets.firstWhere((s) => s.id == 'b');
      expect(a.content, 'old-version');
      expect(a.name, 'cmd-old');
      expect(b.content, 'untouched'); // 其余片段不动
      expect(git.commitAndPushCallCount, 1);
      expect(git.commitMessages.single, contains('restore'));
    });

    test('恢复不存在的片段 id 时无操作', () async {
      await storage.saveSnippets(
          [Snippet(id: 'a', name: 'cmd', content: 'x')]);
      final provider = build();
      await provider.loadSnippets();

      await provider.restoreSnippet(
          'missing', Snippet(id: 'missing', name: 'z', content: 'z'));

      expect(git.commitAndPushCallCount, 0);
    });
  });
}
