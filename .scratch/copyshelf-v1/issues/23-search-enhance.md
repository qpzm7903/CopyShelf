Status: done (v0.1.19)

# 23: 搜索增强（#tag 过滤 + 命中高亮）

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.18 位（因 v0.1.18 用于 bug-M2 修复而顺延至 v0.1.19）

## What was built

- `utils/search_query.dart`：parseSearchQuery 分离 #tag 与自由文本；matchesTags（全部标签约束子串命中）；
  highlightRanges（不区分大小写子串命中区间，拼音命中不高亮——无法逐字对应）。
- Provider _applyFilter 先按 #tag 精确过滤片段标签，再按自由文本查索引；searchText getter 供高亮。
- 搜索窗名称改 RichText，命中字符高亮（强调色 + 底色）。

## Acceptance criteria

- [x] search_query 单元测试 14 例（解析/标签匹配/高亮区间）
- [x] Provider #tag 过滤 3 例（单 tag / tag+关键词 / searchText 剥离）
- [x] 全部 233 测试通过，`flutter analyze` 零 error/warning
