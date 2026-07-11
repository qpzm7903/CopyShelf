Status: done (v0.1.9)

# 13: 终端多行粘贴确认（安全护栏）

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.9（评审后从原 v0.1.17 前移）

## What was built

- `lib/utils/terminal_paste_guard.dart`：纯判定逻辑——多行内容 × 终端进程 = 需确认；
  「不再提醒」后直通。终端名单（cmd/powershell/pwsh/WindowsTerminal/conhost/mintty/alacritty）。
- `win32_window.dart` 新增 HWND→PID（GetWindowThreadProcessId）与
  PID→进程名（QueryFullProcessImageName）解析；TargetWindowService 捕获时一并记录进程名。
- SnippetProvider 注入 targetProcessName seam；搜索窗回车/点击/Alt+N 统一走
  `_pasteAt` → 需确认时先弹框（内容预览 + 不再提醒复选 + 仍然粘贴/取消）。
- 「不再提醒」持久化到 shared_preferences。

## Acceptance criteria

- [x] 判定纯函数测试 7 例（多行×终端、大小写、单行直通、\r\n、非终端、null、抑制）
- [x] Windows CI 冒烟：解析自身进程名返回 .exe 文件名（macOS skip）
- [x] widget 测试 6 例：弹框拦截、确认粘贴、取消、不再提醒持久化+下次直通、非终端直通、单行直通
- [x] 全部 108 测试通过，`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 真实 Windows Terminal 前台时呼出并粘贴多行片段出现确认框
