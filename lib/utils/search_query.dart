/// 搜索查询解析（纯逻辑，可独立测试）
///
/// 支持 `#tag` 语法过滤标签，可与自由关键词组合：
///   `#git push`  → 标签含 git 且正文/名称含 push
///   `#git #wip`  → 同时命中两个标签
class SearchQuery {
  /// 需要匹配的标签（小写，去 # 前缀）
  final List<String> tags;

  /// 自由关键词（去掉 #tag 后的剩余文本，小写、去多余空白）
  final String text;

  const SearchQuery({required this.tags, required this.text});

  bool get isEmpty => tags.isEmpty && text.isEmpty;
}

/// 解析查询串为标签与自由文本。
SearchQuery parseSearchQuery(String raw) {
  final tags = <String>[];
  final textParts = <String>[];
  for (final token in raw.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    if (token.length > 1 && token.startsWith('#')) {
      tags.add(token.substring(1).toLowerCase());
    } else if (token == '#') {
      // 孤立的 # 忽略
      continue;
    } else {
      textParts.add(token);
    }
  }
  return SearchQuery(
    tags: tags,
    text: textParts.join(' ').toLowerCase(),
  );
}

/// 片段标签是否满足查询中的全部标签约束（每个约束子串命中任一标签）。
bool matchesTags(List<String> snippetTags, List<String> queryTags) {
  if (queryTags.isEmpty) return true;
  final lowered = snippetTags.map((t) => t.toLowerCase()).toList();
  return queryTags.every((q) => lowered.any((t) => t.contains(q)));
}

/// 计算 [text] 中 [query] 的（不区分大小写）子串命中区间，用于高亮。
/// 无命中返回空列表。只匹配直接子串，拼音命中不高亮（诚实：无法逐字对应）。
List<(int, int)> highlightRanges(String text, String query) {
  if (query.isEmpty) return const [];
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final ranges = <(int, int)>[];
  var from = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, from);
    if (idx == -1) break;
    ranges.add((idx, idx + lowerQuery.length));
    from = idx + lowerQuery.length;
  }
  return ranges;
}
