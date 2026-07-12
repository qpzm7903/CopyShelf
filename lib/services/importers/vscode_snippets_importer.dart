import 'dart:io';
import 'package:json5/json5.dart';
import 'importer.dart';

/// VS Code 用户 snippets 导入（JSONC）。
///
/// 文件形如：
/// {
///   // 注释
///   "Print": { "prefix": "log", "body": ["console.log($1);", "$2"],
///              "description": "..." }
/// }
/// body 数组按 \n 拼接；tabstop 转为本应用占位符（见 [convertTabstops]）。
class VsCodeSnippetsImporter extends Importer {
  final String? filePath;
  final String? _inlineContent;

  VsCodeSnippetsImporter({this.filePath}) : _inlineContent = null;

  /// 直接传入文件内容（测试用）
  VsCodeSnippetsImporter.fromContent(String content)
      : _inlineContent = content,
        filePath = null;

  @override
  String get displayName => 'VS Code 片段';

  @override
  Future<List<ImportCandidate>> discover() async {
    String? raw = _inlineContent;
    if (raw == null) {
      final path = filePath;
      if (path == null) return const [];
      final file = File(path);
      if (!await file.exists()) return const [];
      raw = await file.readAsString();
    }
    return parse(raw);
  }

  /// 解析 JSONC 文本为候选（纯函数，可测试）。
  static List<ImportCandidate> parse(String jsonc) {
    final Object? decoded;
    try {
      decoded = json5Decode(jsonc);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];

    final result = <ImportCandidate>[];
    decoded.forEach((key, value) {
      if (value is! Map) return;
      final body = value['body'];
      final content = _bodyToString(body);
      if (content.trim().isEmpty) return;
      final prefix = value['prefix'];
      final name = _deriveName(key.toString(), prefix);
      result.add(ImportCandidate(
        name: name,
        content: convertTabstops(content),
        preEscaped: true,
      ));
    });
    return result;
  }

  static String _bodyToString(Object? body) {
    if (body is String) return body;
    if (body is List) return body.map((e) => e.toString()).join('\n');
    return '';
  }

  static String _deriveName(String key, Object? prefix) {
    final p = prefix is List
        ? (prefix.isNotEmpty ? prefix.first.toString() : '')
        : (prefix?.toString() ?? '');
    if (p.isEmpty) return key;
    return '$key ($p)';
  }

  /// 把 VS Code tabstop 语法转成本应用占位符，同时把 body 里的字面大括号转义。
  ///
  /// 规则：
  /// - `${1:x}` → `{x}`（用默认文本命名）
  /// - `${1|a,b|}` → `{arg1:a}`（choice 取第一项作默认值）
  /// - `$1` / `${1}` → `{arg1}`
  /// - `$0` / `${0}` → 丢弃（最终光标位）
  /// - `$VAR` / `${VAR:...}`（大写变量，如 TM_SELECTED_TEXT）→ 丢弃占位，保留默认值
  /// - 其余字面 `{` `}` → `{{` `}}`
  static String convertTabstops(String body) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < body.length) {
      final ch = body[i];
      if (ch == r'$') {
        final consumed = _tryParseTabstop(body, i, buffer);
        if (consumed > 0) {
          i += consumed;
          continue;
        }
      }
      if (ch == '{') {
        buffer.write('{{');
      } else if (ch == '}') {
        buffer.write('}}');
      } else {
        buffer.write(ch);
      }
      i++;
    }
    return buffer.toString();
  }

  /// 尝试从 [start]（'$' 位置）解析一个 tabstop，写入 [out]。
  /// 返回消耗的字符数；不是 tabstop 返回 0。
  static int _tryParseTabstop(String body, int start, StringBuffer out) {
    // $N 简单形式
    final simple = RegExp(r'\$(\d+)').matchAsPrefix(body, start);
    if (simple != null) {
      final n = int.parse(simple.group(1)!);
      if (n != 0) out.write('{arg$n}');
      return simple.group(0)!.length;
    }
    // ${...} 复杂形式：手动找配对的 }
    if (start + 1 < body.length && body[start + 1] == '{') {
      final close = _matchBrace(body, start + 1);
      if (close != -1) {
        final inner = body.substring(start + 2, close);
        out.write(_convertBracedTabstop(inner));
        return close - start + 1;
      }
    }
    return 0;
  }

  /// 从 openIndex（'{'）找配对的 '}'，支持一层嵌套；找不到返回 -1。
  static int _matchBrace(String body, int openIndex) {
    var depth = 0;
    for (var i = openIndex; i < body.length; i++) {
      if (body[i] == '{') depth++;
      if (body[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  static String _convertBracedTabstop(String inner) {
    // choice：N|a,b,c|
    final choice = RegExp(r'^(\d+)\|(.+)\|$').firstMatch(inner);
    if (choice != null) {
      final n = choice.group(1)!;
      final first = choice.group(2)!.split(',').first.trim();
      return n == '0' ? '' : '{arg$n:$first}';
    }
    // N:default
    final withDefault = RegExp(r'^(\d+):(.*)$').firstMatch(inner);
    if (withDefault != null) {
      final n = withDefault.group(1)!;
      final def = withDefault.group(2)!;
      if (n == '0') return def; // 最终光标位保留其默认文本
      return def.isEmpty ? '{arg$n}' : '{$def}';
    }
    // 纯数字 N
    final plain = RegExp(r'^(\d+)$').firstMatch(inner);
    if (plain != null) {
      final n = plain.group(1)!;
      return n == '0' ? '' : '{arg$n}';
    }
    // 变量 VAR 或 VAR:default → 丢弃变量，保留默认值文本
    final variable = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(?::(.*))?$')
        .firstMatch(inner);
    if (variable != null) {
      return variable.group(1) ?? '';
    }
    // 无法识别：原样保留但转义大括号，避免破坏
    return '{{$inner}}';
  }
}
