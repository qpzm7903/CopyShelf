Status: done (v0.1.22)

# 26: 性能兜底 + bug-M2 剩余修复收尾

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.22

## Fixes（bug 审查里程碑 2 剩余 MEDIUM）

- convertTabstops 反斜杠转义：`\$5`/`\{`/`\}`/`\\` 视为字面，不误转占位符。
- convertTabstops 非花括号命名变量 `$CURRENT_YEAR`/`$TM_FILENAME` 丢弃（原样残留 bug）。
- convertTabstops 嵌套默认值 `${1:${2:foo}}` 递归转换为 `{foo}`（原生成乱码字面）。
- snippetHistory 去重键改 jsonEncode（覆盖 name/content/description/tags）：
  仅改 tags 的版本作独立历史点保留；消除空格拼接的撞键歧义。

## 性能

- 500 片段搜索基准测试：CI 断言功能正确（关键词 + #tag 过滤结果），
  性能取 20 次中位数、阈值放宽 50ms（防明显退化，不做严格门禁）。

## Acceptance criteria

- [x] convertTabstops 新增 3 组回归测试（反斜杠/命名变量/嵌套默认值）
- [x] snippetHistory 去重键 2 组回归（仅改 tags 保留 / 拼接歧义不撞键）
- [x] 500 片段搜索基准 + 正确性断言
- [x] 全部 259 测试通过，`flutter analyze` 零 error/warning
