# Bug 审查（里程碑 2，v0.1.9..v0.1.15）确认清单

## 修复中 / 已修复

- [x] **HIGH git 分支不一致测试在 Windows CI 挂**（裸仓库 HEAD symref 过时）
  → v0.1.18 改用 ls-remote --heads 实际分支列表判断。
- [x] **HIGH 模板回归（最要紧）**：_pasteAt 对每条片段无条件跑 userInputPlaceholders，
  历史/手输的含字面大括号片段（kubectl jsonpath='{...}'、JSON）被误当模板，粘贴内容被破坏。
  → v0.1.18 修复：Snippet.isTemplate 开关（默认 false=逐字粘贴），只有模板片段才渲染。
- [x] **HIGH 导入去重比较转义前内容**：含大括号命令重复导入堆叠。
  → v0.1.18 一并修：去重按最终入库内容比较。

## 待修复（后续版本）

- [ ] **MEDIUM convertTabstops 未处理反斜杠转义**：`\$5` 被误转成占位符。
- [x] **MEDIUM convertTabstops 非花括号命名变量** `$CURRENT_YEAR` 原样残留（应丢弃）。
- [x] **MEDIUM convertTabstops 嵌套默认值** `${1:${2:foo}}` 生成乱码字面。
- [x] **MEDIUM snippetHistory 去重键**忽略 description/tags 且空格拼接有碰撞 → 用 jsonEncode。
- [ ] **HIGH（部分）Clipboard.getData 无 try**：粘贴路径异常/挂起（与 M1 git 超时同类）。

## 说明

isTemplate 引入后，导入内容不再需要全量转义：PowerShell 候选=非模板逐字，
VS Code 候选=模板（convertTabstops 输出）。candidateToSnippetContent 相应简化。
