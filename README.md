# CopyShelf

Windows 片段启动器（snippet launcher）— 快速搜索并粘贴你预先配置的文本片段。

## 使用场景

常用的文本片段（Git 命令、代码片段、LLM prompt、回复话术...）散落在笔记、聊天记录、终端历史里，每次要用都要翻找。CopyShelf 让你把它们集中管理：按一个快捷键呼出搜索框，输入关键词，回车即粘贴到当前窗口。

> CopyShelf 不是剪贴板历史工具——它不捕获系统剪贴板的复制历史，只管理你主动配置的片段。

## 功能

- **快捷键呼出**：默认 `Ctrl+Alt+V`，可自定义
- **类 Spotlight 搜索**：输入关键词实时过滤，按使用频率自动排序
- **一键粘贴**：选中片段后自动写入剪贴板 + 模拟 Ctrl+V 粘贴到呼出时的目标窗口

> 注意：粘贴片段会占据系统剪贴板（不恢复之前的内容）。粘贴过的片段留在剪贴板里，可以再次 Ctrl+V。
- **片段管理**：在设置页面添加、编辑、删除片段
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
3. 如果没有片段，右键托盘图标 → 设置 → 添加片段
4. 也可以直接编辑 `%USERPROFILE%\.copyshelf\snippets.json`

## 技术栈

- **Flutter**（Windows 桌面）
- **Provider**（状态管理）
- **SharedPreferences**（设置存储）
- **Win32 API**（剪贴板 + 模拟按键）

## 版本

当前版本：v0.1.0（开发中）

## License

MIT
