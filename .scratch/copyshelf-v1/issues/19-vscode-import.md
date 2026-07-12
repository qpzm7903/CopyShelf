Status: done (v0.1.15)

# 19: VS Code snippets 导入

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.15

## What was built

- `vscode_snippets_importer.dart`：json5 包解析 JSONC（注释 + trailing comma，禁止手写剥离）。
  body 数组按 \n 拼接；名称取 key + prefix。
- convertTabstops（单遍扫描，边转 tabstop 边转义字面大括号，解决交互缺口）：
  $1→{arg1}、$0 丢弃、${1:x}→{x}、${1|a,b|}→{arg1:a}、${VAR:def}→def、字面 {}→{{}}。
- ImportCandidate 加 preEscaped 标志：VS Code 候选已是最终模板形态，入库不再二次转义
  （否则会把生成的 {arg1} 转义坏）。PowerShell 候选仍走转义。
- 设置页「导入」改为来源选择（PowerShell 历史 / VS Code 片段，后者输入文件路径）。

## Acceptance criteria

- [x] convertTabstops 单元测试 8 例（各 tabstop 形式、变量、字面大括号、混合）
- [x] JSONC 解析测试 7 例（注释/多行 body/字符串 body/字面大括号/无 prefix/trailing comma/非法 JSON/preEscaped 不二次转义）
- [x] 全部 200 测试通过，`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 真实 .code-snippets 文件导入
