Status: done (v0.1.17)

# 21: 深色模式

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.17

## What was built

- 真实暗色 ThemeData（暗色 token：canvas/surface/ink/hairline/accentTint）。
- AppTheme.xOf(context) 亮暗解析器（自绘组件按 brightness 取色）。
- ThemeController（三态：跟随系统/亮/暗，持久化 shared_preferences，通知刷新）。
- main.dart MultiProvider 注入 ThemeController，MaterialApp.themeMode 跟随。
- 搜索窗关键 surface（搜索栏/列表）改用解析器，暗色下真正变暗。
- 设置页「常规」分区 SegmentedButton 三态切换。

## Acceptance criteria

- [x] ThemeController 单元测试 4 例（默认跟随/持久化往返/三态/通知）
- [x] 搜索窗暗色/亮色背景 widget 断言各 1 例
- [x] 全部 214 测试通过，`flutter analyze` 零 error/warning
