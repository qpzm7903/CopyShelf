# Bug 审查（里程碑 1，v0.1.2..v0.1.9）确认清单

> workflow 三维 finder + 对抗验证产出。9 条确认（部分跨维度重复合并）。
> 排期：HIGH 尽快，MEDIUM 分批排入后续版本。

## 已修复

- [x] **HIGH 鼠标点击绕过终端护栏**（search_overlay onTap 直接 useSnippet，不经 _pasteAt）
  → v0.1.11 修复：onTap 收敛到 _pasteAt。

## 待修复（排入后续版本）

- [ ] **HIGH 单实例锁误判**（main.dart）：端口 48632 被无关程序占用时静默 exit(0)，应用永不启动。
  修复：wake 协议加 ack 握手，notifyExisting 只在收到 ack 才 true；main 收不到 ack 时降级为无锁启动。→ 排 v0.1.12 或独立补丁版。
- [ ] **MEDIUM git 分支不一致静默失效**（git_service.pull）：本地 master + 远端 main 时
  pull 命中 "couldn't find remote ref" 被当成功，各推各分支永不互通。
  修复：命中该输出时查 _remoteDefaultBranch，非空远端则返回可读错误。→ 排 v0.1.13/同步可视化附近。
- [ ] **MEDIUM git 无超时/交互挂起**（git_service._git）：SSH 首连或凭据询问永久挂起。
  修复：environment 设 GIT_TERMINAL_PROMPT=0 / GIT_SSH_COMMAND BatchMode；Process.start + timeout + kill。
- [x] **MEDIUM 注册表只读权限/全新 profile**（autostart read 用 allAccess 且 openPath 在 try 外）：
  受限环境 settings 页整体加载失败。修复：read 用 readOnly 打开且纳入 try。
- [ ] **MEDIUM 热键先持久化后注册**（settings_page._changeHotkey）：注册失败时坏组合已写盘、
  旧热键已注销，跨重启持续失效。修复：注册成功才持久化，失败回滚重注册旧组合。

## 未完成验证（workflow 因 session 限额中断，待复核）

- Alt+N 直达时物理 Alt 仍按下 → 目标窗口收到 Alt+V 而非 V（若成立，Alt+数字直达可能实际粘不进去）。
- 呼出热键 Alt 未松开时按数字误触直达粘贴。
- HotkeyService.stop() 无法终止阻塞在 GetMessage 的 Isolate。
- 终端确认框打开期间窗口失焦自动隐藏，模态残留。
