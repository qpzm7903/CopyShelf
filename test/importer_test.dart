import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/importers/importer.dart';
import 'package:copyshelf/services/importers/powershell_history_importer.dart';

void main() {
  group('escapeLiteralBraces', () {
    test('字面大括号转义为双大括号', () {
      expect(escapeLiteralBraces('if (x) { y(); }'), 'if (x) {{ y(); }}');
    });

    test('无大括号原样返回', () {
      expect(escapeLiteralBraces('git status'), 'git status');
    });
  });

  group('candidateToSnippetContent', () {
    test('含大括号的导入内容被转义（避免误当占位符）', () {
      const c = ImportCandidate(name: 'x', content: 'echo {var}');
      expect(candidateToSnippetContent(c), 'echo {{var}}');
    });

    test('无大括号内容不变', () {
      const c = ImportCandidate(name: 'x', content: 'git pull');
      expect(candidateToSnippetContent(c), 'git pull');
    });
  });

  group('dedupeCandidates', () {
    test('与库中已有内容重复的候选被过滤', () {
      final candidates = [
        const ImportCandidate(name: 'a', content: 'git status'),
        const ImportCandidate(name: 'b', content: 'git pull'),
      ];
      final result = dedupeCandidates(candidates, {'git status'});

      expect(result.map((c) => c.content), ['git pull']);
    });

    test('候选内部重复也去重', () {
      final candidates = [
        const ImportCandidate(name: 'a', content: 'dup'),
        const ImportCandidate(name: 'b', content: 'dup'),
      ];
      expect(dedupeCandidates(candidates, {}), hasLength(1));
    });
  });

  group('PowerShell 历史解析', () {
    test('按频次聚合去重，最常用在前', () {
      final lines = [
        'git status',
        'git status',
        'git status',
        'npm install',
        'npm install',
        'ls',
      ];
      final candidates = PowerShellHistoryImporter.parseHistory(lines);

      expect(candidates.map((c) => c.content).toList(),
          ['git status', 'npm install', 'ls']);
      expect(candidates.first.frequency, 3);
    });

    test('过滤单字符噪声命令', () {
      final candidates =
          PowerShellHistoryImporter.parseHistory(['ls', 'a', 'git pull']);

      expect(candidates.map((c) => c.content), contains('git pull'));
      expect(candidates.map((c) => c.content), contains('ls'));
      expect(candidates.map((c) => c.content), isNot(contains('a')));
    });

    test('行尾反引号续行合并为单条多行命令', () {
      final lines = [
        'git commit -m "long message" `',
        '  --author "me"',
      ];
      final candidates = PowerShellHistoryImporter.parseHistory(lines);

      expect(candidates, hasLength(1));
      expect(candidates.first.content,
          'git commit -m "long message" \n  --author "me"');
    });

    test('片段名取首行首部并截断过长命令', () {
      final long = 'echo ${'x' * 60}';
      final candidates = PowerShellHistoryImporter.parseHistory([long]);

      expect(candidates.first.name.endsWith('…'), isTrue);
      expect(candidates.first.name.length, lessThanOrEqualTo(41));
    });

    test('含字面大括号的历史命令保留原文（入库时才转义）', () {
      final candidates = PowerShellHistoryImporter.parseHistory(
          ['Get-Process | % { \$_.Name }']);

      expect(candidates.first.content, contains('{'));
      // 入库转义
      expect(candidateToSnippetContent(candidates.first), contains('{{'));
    });

    test('topN 截断', () {
      final lines = List.generate(10, (i) => 'command-$i');
      final candidates =
          PowerShellHistoryImporter.parseHistory(lines, topN: 3);

      expect(candidates, hasLength(3));
    });

    test('空历史返回空列表', () {
      expect(PowerShellHistoryImporter.parseHistory([]), isEmpty);
    });
  });
}
