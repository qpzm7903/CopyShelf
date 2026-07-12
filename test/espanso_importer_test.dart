import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/importers/espanso_importer.dart';

void main() {
  group('Espanso YAML 解析', () {
    test('基础 trigger/replace', () {
      const yaml = '''
matches:
  - trigger: ":hello"
    replace: "Hello World"
''';
      final candidates = EspansoImporter.parse(yaml);

      expect(candidates, hasLength(1));
      expect(candidates.first.name, ':hello');
      expect(candidates.first.content, 'Hello World');
      expect(candidates.first.isTemplate, isFalse);
    });

    test('多个 match', () {
      const yaml = '''
matches:
  - trigger: ":a"
    replace: "AAA"
  - trigger: ":b"
    replace: "BBB"
''';
      expect(EspansoImporter.parse(yaml).map((c) => c.content),
          ['AAA', 'BBB']);
    });

    test('多行 replace（YAML 块标量）', () {
      const yaml = '''
matches:
  - trigger: ":sig"
    replace: |
      line 1
      line 2
''';
      final c = EspansoImporter.parse(yaml).first;
      expect(c.content.trimRight(), 'line 1\nline 2');
    });

    test('{{var}} 转为 {var} 并标记为模板', () {
      const yaml = '''
matches:
  - trigger: ":date"
    replace: "Today is {{mydate}}"
''';
      final c = EspansoImporter.parse(yaml).first;
      expect(c.content, 'Today is {mydate}');
      expect(c.isTemplate, isTrue);
    });

    test('含字面大括号但无 {{}} 变量：非模板逐字', () {
      const yaml = '''
matches:
  - trigger: ":json"
    replace: '{ "k": "v" }'
''';
      final c = EspansoImporter.parse(yaml).first;
      expect(c.content, '{ "k": "v" }');
      expect(c.isTemplate, isFalse);
    });

    test('缺 replace 的 match 跳过', () {
      const yaml = '''
matches:
  - trigger: ":noreplace"
  - trigger: ":ok"
    replace: "value"
''';
      expect(EspansoImporter.parse(yaml), hasLength(1));
    });

    test('非法 YAML 返回空列表', () {
      expect(EspansoImporter.parse(':::not yaml:::\n  - broken'), isEmpty);
    });

    test('无 matches 键返回空', () {
      expect(EspansoImporter.parse('other: 1'), isEmpty);
    });
  });

  group('scoop manifest 结构', () {
    test('scoop/copyshelf.json 结构与 URL 模板正确', () {
      final file = File('scoop/copyshelf.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(json['homepage'], contains('qpzm7903/CopyShelf'));
      expect(json['bin'], 'copyshelf.exe');

      final url = (json['architecture']['64bit']['url']) as String;
      expect(url, contains('releases/download/'));
      expect(url, endsWith('-windows-x86_64.zip'));

      // autoupdate 用 $version 模板指向 Releases zip（与 CI 产物命名一致）
      final autoUrl =
          json['autoupdate']['architecture']['64bit']['url'] as String;
      expect(autoUrl, contains(r'v$version'));
      expect(autoUrl, endsWith(r'CopyShelf-$version-windows-x86_64.zip'));

      expect(json['checkver']['github'], contains('qpzm7903/CopyShelf'));
    });
  });
}
