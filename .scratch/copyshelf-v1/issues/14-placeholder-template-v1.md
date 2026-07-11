Status: done (v0.1.10)

# 14: 占位符模板 v1

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.10

## What was built

- `lib/utils/template.dart`：纯逻辑解析/渲染。
  - `{名称}` 占位符；`{{`/`}}` 转义为字面 `{`/`}`；未闭合、空名 `{}`、跨行大括号按字面处理。
  - `parsePlaceholders`（去重保序）/ `hasPlaceholders` / `renderTemplate`（缺失值→空串，值不二次解析）。
- 搜索窗粘贴链路：有占位符先弹填表框（自管理 controller 的 StatefulWidget，
  逐项 label + autofocus 首项 + 末项回车提交），渲染后再走终端多行护栏与粘贴。
  无占位符也渲染以反转义字面大括号（导入的代码片段常含 `{{ }}`）。
- Provider `useSnippet` / `needsTerminalPasteConfirm` 增加 contentOverride：
  统计记片段本身，粘贴与终端判定用渲染后内容。

## Acceptance criteria

- [x] 解析器 12 测试（提取/去重/转义/未闭合/跨行/中文/渲染各分支）
- [x] 填表 widget 6 测试（单/多占位符、取消、无占位符、字面转义、渲染后多行触发终端确认）
- [x] 全部 126 测试通过，`flutter analyze` 零 error/warning

## 附带修复

- 注册表 read/delete 捕获放宽为 catch-all（win32 GetLastError 跨调用残留导致
  v0.1.8 CI 的真实注册表测试偶发 0x80070002），并去掉测试易抖的前置 null 断言。
