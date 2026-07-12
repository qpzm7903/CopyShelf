import '../../utils/template.dart';

/// 一条导入候选（来源解析出的、待用户勾选入库的条目）
class ImportCandidate {
  final String name;
  final String content;

  /// 该内容在来源中出现的次数（用于排序，越常用越靠前）
  final int frequency;

  const ImportCandidate({
    required this.name,
    required this.content,
    this.frequency = 1,
  });
}

/// 导入来源统一接口：解析来源 → 候选列表。UI 负责勾选与批量入库。
abstract class Importer {
  /// 展示名（如「PowerShell 历史」）
  String get displayName;

  /// 解析并返回候选（已排序，最常用在前）。来源不存在时返回空列表。
  Future<List<ImportCandidate>> discover();
}

/// 把导入内容里的字面 `{`/`}` 转义为 `{{`/`}}`，避免误触发占位符填表。
/// 已经是 `{{`/`}}` 的不再重复转义。
String escapeLiteralBraces(String content) {
  final buffer = StringBuffer();
  for (var i = 0; i < content.length; i++) {
    final ch = content[i];
    if (ch == '{' || ch == '}') {
      buffer.write(ch == '{' ? '{{' : '}}');
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// 过滤掉与已有内容重复的候选（按转义后最终内容比较）。
/// [existingContents] 是库中已有片段的 content 集合。
List<ImportCandidate> dedupeCandidates(
  List<ImportCandidate> candidates,
  Set<String> existingContents,
) {
  final seen = <String>{...existingContents};
  final result = <ImportCandidate>[];
  for (final c in candidates) {
    if (seen.add(c.content)) result.add(c);
  }
  return result;
}

/// 候选最终入库的内容：字面大括号转义，使导入的代码/命令不会被当模板解析。
String candidateToSnippetContent(ImportCandidate c) =>
    hasPlaceholders(c.content) || c.content.contains('{')
        ? escapeLiteralBraces(c.content)
        : c.content;
