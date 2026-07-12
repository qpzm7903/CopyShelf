import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

/// 大列表搜索的功能正确性 + 性能兜底。
/// CI 门禁只断言正确性；毫秒阈值宽松（共享 runner 抖动大），仅防明显退化。
void main() {
  test('500 片段搜索：结果正确且预热后中位数在宽松预算内', () async {
    final storage = MockStorageService();
    final snippets = [
      for (var i = 0; i < 500; i++)
        Snippet(
          id: 'id-$i',
          name: 'snippet number $i ${i % 7 == 0 ? 'deploy' : 'misc'}',
          content: 'echo command $i',
          tags: i % 5 == 0 ? ['git'] : ['other'],
        ),
    ];
    await storage.saveSnippets(snippets);
    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await provider.loadSnippets();

    // 正确性：关键词过滤
    provider.setSearchQuery('deploy');
    expect(provider.filteredSnippets.isNotEmpty, isTrue);
    expect(
        provider.filteredSnippets.every((s) => s.name.contains('deploy')),
        isTrue);

    // 正确性：#tag 过滤
    provider.setSearchQuery('#git');
    expect(provider.filteredSnippets.length, 100); // 每 5 个一个 git

    // 性能兜底：多次查询取中位数，阈值放宽到 50ms 量级
    provider.setSearchQuery('');
    final samples = <int>[];
    for (var run = 0; run < 20; run++) {
      final sw = Stopwatch()..start();
      provider.setSearchQuery('command ${run % 500}');
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
    }
    samples.sort();
    final medianMs = samples[samples.length ~/ 2] / 1000.0;
    expect(medianMs, lessThan(50),
        reason: '搜索中位数 ${medianMs}ms 超出宽松预算，疑似性能退化');
  });
}
