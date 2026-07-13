Status: done (v0.1.24)

# 28: 标签过滤侧栏

## Parent

ROADMAP-20 收官后的产品迭代（用户参考竞品截图提出：搜索窗要有可视化的按标签过滤）。

## What was built

- `models/tag_filter.dart`：TagFilter 值对象，三种取值——全部 / 无标签 / 指定标签；
  指定标签为不区分大小写的**精确匹配**（区别于 `#tag` 搜索语法的子串匹配），带值相等语义供选中态比较。
- Provider：`tagFilter` 状态 + `setTagFilter`；`allTags`（大小写不敏感去重、字典序、保留首次写法）；
  `hasUntaggedSnippets`；`_applyFilter` 先按侧栏标签过滤再走关键词/#tag 逻辑（AND 叠加）；
  `showSearch()` 呼出时重置为「全部」（与清空搜索词一致）。
- 搜索窗：左侧 128px 标签栏（全部 / 无标签 / 各标签），选中项强调色高亮；
  库中没有任何标签时不渲染侧栏，保持极简单栏布局；「无标签」项仅在存在无标签片段时显示；
  切换标签重置列表选中到第一条；标签下搜索无结果时提示「该标签下没有匹配的片段」。

## Acceptance criteria

- [x] TagFilter 单元测试 5 例（matches 三种取值 / 精确非子串 / 相等性）
- [x] Provider 标签过滤 7 例（allTags 去重排序 / 无标签 / 与关键词叠加 / showSearch 重置）
- [x] 侧栏 widget 测试 8 例（显隐规则 / 点击过滤 / 叠加 / 空态文案）
- [x] 全部 281 测试通过，`flutter analyze` 无新增告警

## Follow-ups（未做，观察需求）

- 键盘切换标签（如 Ctrl+Tab 循环）——键盘党目前可用 `#tag` 语法覆盖
- 标签计数徽标、标签自定义排序/颜色
