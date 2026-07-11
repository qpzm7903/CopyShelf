import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/utils/template.dart';

void main() {
  group('parsePlaceholders', () {
    test('提取占位符名称并保持出现顺序', () {
      expect(
        parsePlaceholders('git commit -m "{message}" --author "{author}"'),
        ['message', 'author'],
      );
    });

    test('重复占位符去重', () {
      expect(parsePlaceholders('{name} meets {name} and {other}'),
          ['name', 'other']);
    });

    test('双大括号 {{ }} 是字面量转义，不算占位符', () {
      expect(parsePlaceholders('if (x) {{ return; }}'), isEmpty);
      expect(parsePlaceholders('{{literal}} but {real}'), ['real']);
    });

    test('未闭合的 { 与空名 {} 不算占位符', () {
      expect(parsePlaceholders('a { b'), isEmpty);
      expect(parsePlaceholders('a {} b'), isEmpty);
    });

    test('跨行的大括号不算占位符', () {
      expect(parsePlaceholders('a {first\nsecond} b'), isEmpty);
    });

    test('中文占位符名', () {
      expect(parsePlaceholders('你好 {姓名}'), ['姓名']);
    });

    test('无占位符', () {
      expect(hasPlaceholders('plain text'), isFalse);
      expect(hasPlaceholders('has {one}'), isTrue);
    });
  });

  group('renderTemplate', () {
    test('替换全部占位符', () {
      expect(
        renderTemplate('git commit -m "{message}"', {'message': 'fix bug'}),
        'git commit -m "fix bug"',
      );
    });

    test('同名占位符全部替换', () {
      expect(
        renderTemplate('{name} meets {name}', {'name': 'Alice'}),
        'Alice meets Alice',
      );
    });

    test('{{ }} 渲染为字面 { }', () {
      expect(
        renderTemplate('if ({cond}) {{ return; }}', {'cond': 'x > 0'}),
        'if (x > 0) { return; }',
      );
    });

    test('缺失的值替换为空字符串', () {
      expect(renderTemplate('a {miss} b', {}), 'a  b');
    });

    test('值本身包含大括号时原样输出，不再解析', () {
      expect(
        renderTemplate('{code}', {'code': 'if (x) { y(); }'}),
        'if (x) { y(); }',
      );
    });
  });
}
