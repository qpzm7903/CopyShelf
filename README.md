# CopyShelf

Windows 剪贴板指令管理器 — 快速搜索并粘贴你配置的指令/命令片段。

## 使用场景

经常复制内容到剪贴板，但复制多了旧内容就被覆盖了？CopyShelf 让你提前配置好常用的文本指令（Git 命令、代码片段、回复话术...），按一个快捷键就能搜索并粘贴，不需要再到处翻历史。

## 功能

- **快捷键呼出**：默认 `Ctrl+Alt+V`，可自定义
- **类 Spotlight 搜索**：输入关键词实时过滤，按使用频率自动排序
- **一键粘贴**：选中指令后自动写入剪贴板 + 模拟 Ctrl+V 粘贴到前台窗口
- **指令管理**：在设置页面添加、编辑、删除指令
- **Git 多设备同步**：自动 commit/push/pull，不同设备间数据保持一致
- **系统托盘常驻**：后台运行，随时响应

## 快速开始

> 需要 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) 3.10+

```bash
# 克隆仓库
git clone https://github.com/qpzm7903/CopyShelf.git
cd CopyShelf

# 安装依赖
flutter pub get

# 运行（调试模式）
flutter run -d windows

# 构建发布版
flutter build windows --release
```

构建产物在 `build\windows\x64\runner\Release\` 目录下。

## 首次使用

1. 启动 CopyShelf，它将常驻系统托盘
2. 按 `Ctrl+Alt+V` 呼出搜索框
3. 如果没有指令，右键托盘图标 → 设置 → 添加指令
4. 也可以直接编辑 `%USERPROFILE%\.copyshelf\commands.json`

## 技术栈

- **Flutter**（Windows 桌面）
- **Provider**（状态管理）
- **SharedPreferences**（设置存储）
- **Win32 API**（剪贴板 + 模拟按键）

## 版本

当前版本：v0.1.0（开发中）

## License

MIT
