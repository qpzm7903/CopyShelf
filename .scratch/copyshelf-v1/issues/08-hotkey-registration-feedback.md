Status: done (v0.1.3)

# 08: 快捷键注册失败提示与降级

## Parent

`.scratch/copyshelf-v1/PRD.md` / `.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.3

## What to build

热键注册失败（被其他程序占用）时不再静默。修复过程中发现旧协议 bug：
Isolate 用裸 bool 同时表示「注册结果」和「热键触发」，注册成功的握手消息
会被当成一次热键触发；且 `start()` 硬等 500ms 后无条件返回 true，失败完全静默。

## What was built

- 新增 `lib/services/hotkey_messages.dart`：带 type 字段的消息协议 +
  `HotkeyMessageDispatcher`（纯 Dart 可测试），注册结果与触发消息可区分，
  超时（3s）视为失败，错误码 1409 映射为「已被其他程序占用」。
- `HotkeyService.start/updateHotkey` 返回 `HotkeyRegistration`（ok + 可读原因），
  失败时清理 Isolate 资源。
- `SnippetProvider.hotkeyError` 可观察状态；main.dart 启动注册失败时写入。
- 设置页快捷键分区新增错误横幅（`Key('hotkey-error-banner')`）；
  更换快捷键成功清除错误、失败更新错误并提示。

## Acceptance criteria

- [x] `hotkey_registration_test.dart`：注册失败返回失败原因 / 失败状态可被 Provider 观察
- [x] widget 测试：失败状态下设置页渲染错误横幅，清除后消失
- [x] 全部 67 测试通过，`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 用另一程序占用 Ctrl+Alt+V 后启动 CopyShelf，设置页出现红色横幅
- [ ] 更换为未被占用的快捷键后横幅消失且新快捷键生效
