---
name: verify
description: CopyShelf 变更验证指南——本仓库是 Windows-only Flutter 应用，在 macOS 开发机上的验证上限与替代路径。
---

# CopyShelf 验证指南

## 本仓库的验证上限（macOS 开发机）

CopyShelf 只有 `windows/` 平台目标，GUI 运行时验证在 macOS 开发机上**不可达**：

- `flutter build macos` 不可行：开发机只有 Command Line Tools，没有完整 Xcode（`xcode-select -p` → `/Library/Developer/CommandLineTools`），SPM 依赖解析需要 `xcodebuild`。
- Web 目标不可行：`lib/` 大量 `dart:io`（Platform、exit）。
- 代码本身对非 Windows 有守卫（快捷键/托盘/粘贴仅 `Platform.isWindows`），若未来装了 Xcode，`flutter create --platforms=macos` 后应用可以跑起来做 UI 级验证（数据目录默认 `~/.copyshelf`，无远端配置时 Git 仅本地 commit，安全）。

## 实际验证路径（按强度排序）

1. **用户的 Windows 机器手动验证** —— 唯一的真实端到端表面（全局快捷键、Win32 粘贴、托盘）。
2. **发布 CI**（`.github/workflows/build.yml`）：push tag `v*` 后在 `windows-latest` 上跑 `flutter test` 全量 + `flutter build windows --release`，用 `gh run watch` 盯到 Release 产物发出。
3. **本地** `flutter test` + `flutter analyze`（Flutter SDK 在 `~/sdks/flutter-stable/bin`，不在默认 PATH）。widget 测试直接驱动 `SearchOverlay` 等真实页面组件，是本机能达到的最接近 UI 的层。

## 发布流程

```bash
export PATH="$HOME/sdks/flutter-stable/bin:$PATH"
flutter test && flutter analyze          # 本地门禁
git push origin main
git tag v0.1.X && git push origin v0.1.X # 触发 CI 构建 + GitHub Release
gh run watch                             # 盯 test / build-windows / release 三个 job
```

版本号需同步改两处：`pubspec.yaml` 和 `lib/utils/constants.dart`。
