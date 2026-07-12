/// 占位符模板（纯逻辑，可独立测试）
///
/// 语法：
/// - `{名称}`：占位符，粘贴前弹填表对话框逐项填写
/// - `{{` / `}}`：字面 `{` / `}` 的转义（导入的代码片段大量使用字面大括号）
/// - 未闭合的 `{`、空名 `{}`、跨行的大括号：一律按字面文本处理（宽容解析）

/// 模板解析出的一个片段：要么是字面文本，要么是一个占位符名
class _Segment {
  final String text;
  final bool isPlaceholder;
  const _Segment.literal(this.text) : isPlaceholder = false;
  const _Segment.placeholder(this.text) : isPlaceholder = true;
}

List<_Segment> _parse(String content) {
  final segments = <_Segment>[];
  final buffer = StringBuffer();
  var i = 0;

  void flushLiteral() {
    if (buffer.isNotEmpty) {
      segments.add(_Segment.literal(buffer.toString()));
      buffer.clear();
    }
  }

  while (i < content.length) {
    final ch = content[i];
    if (ch == '{' && i + 1 < content.length && content[i + 1] == '{') {
      buffer.write('{');
      i += 2;
      continue;
    }
    if (ch == '}' && i + 1 < content.length && content[i + 1] == '}') {
      buffer.write('}');
      i += 2;
      continue;
    }
    if (ch == '{') {
      final close = content.indexOf('}', i + 1);
      final name = close == -1 ? null : content.substring(i + 1, close);
      final isValidName = name != null &&
          name.isNotEmpty &&
          !name.contains('{') &&
          !name.contains('\n');
      if (isValidName) {
        flushLiteral();
        segments.add(_Segment.placeholder(name));
        i = close + 1;
        continue;
      }
    }
    buffer.write(ch);
    i++;
  }
  flushLiteral();
  return segments;
}

/// 提取占位符名称（去重，保持首次出现顺序）
List<String> parsePlaceholders(String content) {
  final seen = <String>{};
  return [
    for (final seg in _parse(content))
      if (seg.isPlaceholder && seen.add(seg.text)) seg.text,
  ];
}

bool hasPlaceholders(String content) => parsePlaceholders(content).isNotEmpty;

/// 用 [values] 渲染模板；缺失的占位符替换为空字符串。
/// 值本身的内容原样输出，不做二次解析。
String renderTemplate(String content, Map<String, String> values) {
  final buffer = StringBuffer();
  for (final seg in _parse(content)) {
    buffer.write(seg.isPlaceholder ? (values[seg.text] ?? '') : seg.text);
  }
  return buffer.toString();
}

// ========== v0.1.11：内置变量 + 默认值 ==========

/// 自动求值、不进填表的内置变量名
const Set<String> _builtinVariables = {
  'date',
  'time',
  'datetime',
  'clipboard',
};

bool isBuiltinVariable(String name) => _builtinVariables.contains(name);

/// 拆分占位符 token 为 (名称, 默认值?)。默认值在第一个冒号之后，
/// 冒号后为空或无冒号则默认值为 null。默认值本身可含冒号。
(String, String?) splitPlaceholder(String raw) {
  final idx = raw.indexOf(':');
  if (idx == -1) return (raw, null);
  return (raw.substring(0, idx), raw.substring(idx + 1));
}

/// 需要用户填表的占位符名（去重保序）：排除内置变量，去掉默认值部分。
List<String> userInputPlaceholders(String content) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in parsePlaceholders(content)) {
    final (name, _) = splitPlaceholder(raw);
    if (isBuiltinVariable(name)) continue;
    if (seen.add(name)) result.add(name);
  }
  return result;
}

/// 提取某占位符的默认值（供填表预填）；无默认值返回空串。
String defaultValueFor(String content, String name) {
  for (final raw in parsePlaceholders(content)) {
    final (n, def) = splitPlaceholder(raw);
    if (n == name) return def ?? '';
  }
  return '';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime t) =>
    '${t.year}-${_pad2(t.month)}-${_pad2(t.day)}';

String _formatTime(DateTime t) =>
    '${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}';

/// 高级渲染：内置变量按 [now]/[clipboard] 求值，自定义占位符用 [userValues]，
/// 用户留空且占位符声明了默认值时回退到默认值；字面 `{{ }}` 反转义。
String renderTemplateAdvanced(
  String content, {
  required Map<String, String> userValues,
  required DateTime now,
  required String clipboard,
}) {
  final buffer = StringBuffer();
  for (final seg in _parse(content)) {
    if (!seg.isPlaceholder) {
      buffer.write(seg.text);
      continue;
    }
    final (name, def) = splitPlaceholder(seg.text);
    switch (name) {
      case 'date':
        buffer.write(_formatDate(now));
      case 'time':
        buffer.write(_formatTime(now));
      case 'datetime':
        buffer.write('${_formatDate(now)} ${_formatTime(now)}');
      case 'clipboard':
        buffer.write(clipboard);
      default:
        final value = userValues[name];
        final resolved =
            (value == null || value.isEmpty) ? (def ?? '') : value;
        buffer.write(resolved);
    }
  }
  return buffer.toString();
}
