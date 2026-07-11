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
