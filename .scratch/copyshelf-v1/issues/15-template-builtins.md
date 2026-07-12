Status: done (v0.1.11)

# 15: 模板内置变量 + 默认值

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.11

## What was built

- template.dart 新增：`{date}` `{time}` `{datetime}` `{clipboard}` 内置变量自动求值不进填表；
  `{名称:默认值}` 语法（第一个冒号分割，默认值可含冒号）。
- `userInputPlaceholders`（过滤内置变量、去默认值、按名去重）/ `defaultValueFor` /
  `renderTemplateAdvanced`（内置变量按 now/clipboard 求值，用户留空回退默认值，字面 {{ }} 反转义）。
- 搜索窗填表只列自定义占位符并预填默认值；渲染读实际剪贴板。

## 附带修复（bug 审查里程碑 1 · HIGH）

- 鼠标点击列表行绕过占位符填表与终端多行护栏：onTap 收敛到 _pasteAt。
  回归测试：终端目标 + 多行片段点击列表行弹确认框且不粘贴。

## Acceptance criteria

- [x] 内置变量/默认值单元测试 13 例
- [x] 搜索窗内置变量 widget 测试 3 例（纯内置不填表、默认值预填、留空用默认值）
- [x] 全部 143 测试通过，`flutter analyze` 零 error/warning
