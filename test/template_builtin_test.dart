import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/utils/template.dart';

void main() {
  final now = DateTime(2026, 7, 11, 14, 30, 45);

  group('内置变量与默认值：拆分', () {
    test('splitDefault：分离占位符名与默认值', () {
      expect(splitPlaceholder('name'), ('name', null));
      expect(splitPlaceholder('name:Alice'), ('name', 'Alice'));
      // 默认值本身含冒号：只在第一个冒号处分割
      expect(splitPlaceholder('url:https://x.com'), ('url', 'https://x.com'));
    });

    test('内置变量识别', () {
      expect(isBuiltinVariable('date'), isTrue);
      expect(isBuiltinVariable('time'), isTrue);
      expect(isBuiltinVariable('datetime'), isTrue);
      expect(isBuiltinVariable('clipboard'), isTrue);
      expect(isBuiltinVariable('name'), isFalse);
    });
  });

  group('needsUserInput：内置变量不进填表', () {
    test('纯内置变量的模板无需填表', () {
      expect(userInputPlaceholders('今天是 {date} {time}'), isEmpty);
    });

    test('自定义占位符仍需填表，内置变量被过滤', () {
      expect(userInputPlaceholders('{greeting} at {time}'), ['greeting']);
    });

    test('带默认值的占位符仍需填表，name 去掉默认值部分', () {
      expect(userInputPlaceholders('hi {name:Bob}'), ['name']);
    });

    test('clipboard 不进填表', () {
      expect(userInputPlaceholders('paste: {clipboard}'), isEmpty);
    });
  });

  group('renderTemplateAdvanced：内置变量求值 + 默认值', () {
    test('date/time/datetime 按 now 求值', () {
      final out = renderTemplateAdvanced(
        '{date} | {time} | {datetime}',
        userValues: {},
        now: now,
        clipboard: '',
      );
      expect(out, '2026-07-11 | 14:30:45 | 2026-07-11 14:30:45');
    });

    test('clipboard 变量注入当前剪贴板', () {
      final out = renderTemplateAdvanced(
        '前缀 {clipboard} 后缀',
        userValues: {},
        now: now,
        clipboard: 'COPIED',
      );
      expect(out, '前缀 COPIED 后缀');
    });

    test('默认值：用户留空时用默认值', () {
      final out = renderTemplateAdvanced(
        'branch: {name:main}',
        userValues: {'name': ''},
        now: now,
        clipboard: '',
      );
      expect(out, 'branch: main');
    });

    test('默认值：用户填了值则覆盖默认值', () {
      final out = renderTemplateAdvanced(
        'branch: {name:main}',
        userValues: {'name': 'dev'},
        now: now,
        clipboard: '',
      );
      expect(out, 'branch: dev');
    });

    test('内置变量与自定义占位符混合', () {
      final out = renderTemplateAdvanced(
        '{greeting}! 现在 {time}',
        userValues: {'greeting': '你好'},
        now: now,
        clipboard: '',
      );
      expect(out, '你好! 现在 14:30:45');
    });

    test('字面 {{ }} 仍反转义', () {
      final out = renderTemplateAdvanced(
        'code {{block}} {x}',
        userValues: {'x': 'v'},
        now: now,
        clipboard: '',
      );
      expect(out, 'code {block} v');
    });

    test('defaultValueFor：提取某占位符的默认值供填表预填', () {
      expect(defaultValueFor('branch: {name:main}', 'name'), 'main');
      expect(defaultValueFor('{name}', 'name'), '');
    });
  });
}
