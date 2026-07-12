Status: done (v0.1.18)

# 22: 模板改为 opt-in + git 分支修复 + 导入去重修复

## Parent

bug 审查里程碑 2（v0.1.9..v0.1.15）确认项。本版为修复版（对应 ROADMAP v0.1.18 位，
搜索增强顺延到 v0.1.19）。

## Fixes

- **HIGH 模板回归**：`_pasteAt` 曾对每条片段无条件解析 {占位符}，
  含字面大括号的命令/JSON（kubectl jsonpath、`{"k":"v"}`）被误当模板、内容被破坏。
  → Snippet.isTemplate 开关（默认 false 逐字粘贴），编辑页加「作为模板」复选框；
  仅模板片段才 userInputPlaceholders + renderTemplateAdvanced。
- **HIGH 导入去重**：dedupeCandidates 曾比较转义前内容，含大括号命令重复导入堆叠。
  → 按最终入库内容比较。isTemplate 引入后非模板逐字入库不再转义，模板候选原样。
  PowerShell 候选=非模板逐字；VS Code 候选=模板。
- **HIGH git 分支测试在 Windows CI 挂**（裸仓库 HEAD symref 过时）→ 改用 ls-remote --heads 实际分支列表。
- Clipboard.getData 加 try（读剪贴板失败退化为空串，不阻断粘贴）。

## Acceptance criteria

- [x] 回归测试：kubectl/JSON 非模板逐字粘贴不弹表单；模板同内容才弹表单；重复导入不堆叠
- [x] git 分支不一致用实际分支列表判断（Windows CI 稳过）
- [x] 全部 219 测试通过，`flutter analyze` 零 error/warning
