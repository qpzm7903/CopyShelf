Status: done (v0.1.20)

# 24: 关于对话框 + 检查更新

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.20

## What was built

- `services/update_checker.dart`：compareVersions（忽略 v 前缀、点分段数字、段数不等）+
  UpdateChecker（GitHub Releases API，注入 http client 可测）。
- 设置页底部「关于」按钮 → 对话框（版本号、开源地址、可用「检查更新」按钮，
  调 API 比对版本并提示，不发死按钮）。
- 附带产出：README.en.md（英文，覆盖全部已发布功能）。

## Acceptance criteria

- [x] compareVersions 单元测试 4 例（语义/v 前缀/主版本/段数不等）
- [x] UpdateChecker mock http 测试 5 例（有新版/最新/本地更新/HTTP 错误/缺 tag）
- [x] 关于对话框 widget 测试 2 例（弹出显示版本+地址/含检查更新按钮）
- [x] 全部 244 测试通过，`flutter analyze` 零 error/warning

## 待实机验证

- [ ] 演示 GIF（需 Windows 实机录制，本机无法生成）
