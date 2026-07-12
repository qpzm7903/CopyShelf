import 'dart:io';
import 'package:yaml/yaml.dart';
import 'importer.dart';

/// Espanso match 文件导入（YAML）。
///
/// 文件形如：
/// matches:
///   - trigger: ":hello"
///     replace: "Hello World"
///   - trigger: ":sig"
///     replace: |
///       多行
///       签名
///   - trigger: ":date"
///     replace: "Today is {{mydate}}"
///
/// trigger → 片段名；replace → 内容；`{{var}}` → 本应用 `{var}` 占位符（模板）。
class EspansoImporter extends Importer {
  final String? filePath;
  final String? _inlineContent;

  EspansoImporter({this.filePath}) : _inlineContent = null;

  EspansoImporter.fromContent(String content)
      : _inlineContent = content,
        filePath = null;

  @override
  String get displayName => 'Espanso';

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

  static final _varPattern = RegExp(r'\{\{\s*([A-Za-z0-9_]+)\s*\}\}');

  /// 解析 YAML 文本为候选（纯函数，可测试）。
  static List<ImportCandidate> parse(String yamlText) {
    final Object? doc;
    try {
      doc = loadYaml(yamlText);
    } catch (_) {
      return const [];
    }
    if (doc is! YamlMap) return const [];
    final matches = doc['matches'];
    if (matches is! YamlList) return const [];

    final result = <ImportCandidate>[];
    for (final m in matches) {
      if (m is! YamlMap) continue;
      final replace = m['replace'];
      if (replace is! String || replace.isEmpty) continue;
      final trigger = m['trigger']?.toString() ?? '';
      final hasVars = _varPattern.hasMatch(replace);
      result.add(ImportCandidate(
        name: _deriveName(trigger, replace),
        content: _convertVars(replace),
        isTemplate: hasVars, // 有 {{var}} 才作为模板
      ));
    }
    return result;
  }

  /// `{{var}}` → `{var}`；无变量则原样（非模板逐字）。
  static String _convertVars(String replace) =>
      replace.replaceAllMapped(_varPattern, (m) => '{${m.group(1)}}');

  static String _deriveName(String trigger, String replace) {
    if (trigger.isNotEmpty) return trigger;
    final firstLine = replace.split('\n').first.trim();
    return firstLine.length <= 40 ? firstLine : '${firstLine.substring(0, 40)}…';
  }
}
