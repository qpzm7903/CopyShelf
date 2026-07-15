import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mocks.dart';

void main() {
  late MockStorageService storage;
  late MockGitService git;

  setUp(() {
    storage = MockStorageService();
    git = MockGitService();
  });

  test('successful copy sets notice, updates stats, and skips git', () async {
    final copied = <String>[];
    final provider = SnippetProvider(
      storage: storage,
      git: git,
      copy: (text) async {
        copied.add(text);
        return true;
      },
    );
    await provider.addSnippet(name: 'snip', content: 'original');
    git.commitAndPushCallCount = 0;

    final success = await provider.copySnippet(
      provider.snippets[0].id,
      contentOverride: 'rendered',
    );

    expect(success, isTrue);
    expect(copied, ['rendered']);
    expect(provider.notice, contains('已复制'));
    expect(provider.statsFor(provider.snippets[0].id).frequency, 1);
    expect(storage.saveStatsCallCount, 1);
    expect(git.commitAndPushCallCount, 0);
  });

  test('failed copy reports an error', () async {
    final provider = SnippetProvider(
      storage: storage,
      git: git,
      copy: (_) async => false,
    );
    await provider.addSnippet(name: 'snip', content: 'content');

    final success = await provider.copySnippet(provider.snippets[0].id);

    expect(success, isFalse);
    expect(provider.error, contains('复制失败'));
  });
}
