Status: done (v0.1.14)

# 18: 导入框架 + PowerShell 历史导入

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.14

## What was built

- `services/importers/importer.dart`：Importer 接口 + ImportCandidate；
  框架级规则 escapeLiteralBraces（字面 {/} → {{/}}）、dedupeCandidates（对已有内容去重）、
  candidateToSnippetContent（含大括号入库前转义，避免误当占位符）。
- `powershell_history_importer.dart`：解析 PSReadLine ConsoleHost_history.txt，
  行尾反引号续行合并、按频次聚合去重、Top N，命令首行首部作片段名。
- Provider.importSnippets（批量入库一次性同步）+ existingContents + buildSnippet。
- `import_page.dart`：候选默认全选、可勾选、显示频次、批量导入；设置页「导入」入口（仅 Windows）。

## Acceptance criteria

- [x] 框架/解析纯函数单元测试 12 例（转义/去重/含大括号/频次聚合/续行合并/命名截断/topN/空）
- [x] 导入页 widget 测试 5 例（默认全选入库/取消勾选/已存在过滤/全存在空态/大括号转义）
- [x] 全部 185 测试通过，`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 真实 PSReadLine 历史文件导入
