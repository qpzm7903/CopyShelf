import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/importers/importer.dart';
import 'package:copyshelf/services/importers/vscode_snippets_importer.dart';

void main() {
  group('convertTabstops', () {
    test(r'$1 / $2 → {arg1} {arg2}', () {
      expect(VsCodeSnippetsImporter.convertTabstops(r'log($1, $2)'),
          'log({arg1}, {arg2})');
    });

    test(r'$0 丢弃', () {
      expect(VsCodeSnippetsImporter.convertTabstops(r'done$0'), 'done');
    });

    test(r'${1:name} → {name}', () {
      expect(VsCodeSnippetsImporter.convertTabstops(r'hi ${1:name}'),
          'hi {name}');
    });

    test(r'${1|a,b,c|} choice 取第一项作默认值', () {
      expect(VsCodeSnippetsImporter.convertTabstops(r'${1|red,green|}'),
          '{arg1:red}');
    });

    test(r'${1} → {arg1}', () {
      expect(VsCodeSnippetsImporter.convertTabstops(r'x ${1} y'), 'x {arg1} y');
    });

    test('字面大括号转义为双大括号', () {
      expect(VsCodeSnippetsImporter.convertTabstops('if (x) { y(); }'),
          'if (x) {{ y(); }}');
    });

    test('tabstop 与字面大括号混合', () {
      expect(
        VsCodeSnippetsImporter.convertTabstops(r'function $1() { return $2; }'),
        'function {arg1}() {{ return {arg2}; }}',
      );
    });

    test(r'变量 ${TM_SELECTED_TEXT} 丢弃，保留默认值', () {
      expect(
          VsCodeSnippetsImporter.convertTabstops(
              r'wrap ${TM_SELECTED_TEXT:x}'),
          'wrap x');
    });
  });

  group('VS Code snippets JSONC 解析', () {
    test('解析含注释与多行 body', () {
      const jsonc = '''
{
  // 打印日志
  "Print to console": {
    "prefix": "log",
    "body": ["console.log('\$1');", "\$2"],
    "description": "Log output"
  }
}
''';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);

      expect(candidates, hasLength(1));
      expect(candidates.first.name, 'Print to console (log)');
      expect(candidates.first.content, "console.log('{arg1}');\n{arg2}");
      expect(candidates.first.preEscaped, isTrue);
    });

    test('body 为字符串（非数组）也支持', () {
      const jsonc = '{"S": {"prefix": "s", "body": "echo \$1"}}';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);

      expect(candidates.first.content, 'echo {arg1}');
    });

    test('含字面大括号的 body 正确转义', () {
      const jsonc =
          r'{"Fn": {"prefix": "fn", "body": "function ${1:name}() { }"}}';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);

      expect(candidates.first.content, 'function {name}() {{ }}');
    });

    test('无 prefix 时用 key 作名称', () {
      const jsonc = '{"MySnippet": {"body": "text"}}';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);

      expect(candidates.first.name, 'MySnippet');
    });

    test('trailing comma（JSONC 宽松）', () {
      const jsonc = '{"A": {"prefix": "a", "body": "x",},}';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);

      expect(candidates, hasLength(1));
    });

    test('非法 JSON 返回空列表不抛异常', () {
      expect(VsCodeSnippetsImporter.parse('not json at all {{{'), isEmpty);
    });

    test('候选入库不被二次转义（preEscaped）', () {
      const jsonc =
          r'{"Fn": {"prefix": "fn", "body": "if (x) { $1 }"}}';
      final candidates = VsCodeSnippetsImporter.parse(jsonc);
      // 转换后：if (x) {{ {arg1} }}
      expect(candidates.first.content, 'if (x) {{ {arg1} }}');
      // 入库保持不变（不再转义 {arg1}）
      expect(candidateToSnippetContent(candidates.first),
          'if (x) {{ {arg1} }}');
    });
  });
}
