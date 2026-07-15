# CopyShelf

Windows 片段启动器（snippet launcher）— 快速搜索并粘贴你预先配置的文本片段。

## 使用场景

常用的文本片段（Git 命令、代码片段、LLM prompt、回复话术...）散落在笔记、聊天记录、终端历史里，每次要用都要翻找。CopyShelf 让你把它们集中管理：按一个快捷键呼出搜索框，输入关键词，回车即粘贴到当前窗口。

> CopyShelf 不是剪贴板历史工具——它不捕获系统剪贴板的复制历史，只管理你主动配置的片段。

## 功能

- **快捷键呼出**：默认 `Ctrl+Alt+V`，可自定义
- **类 Spotlight 搜索**：名称、描述、标签和正文实时过滤，中文支持拼音，按 frecency 自动排序
- **标签过滤**：左侧标签栏一键按标签筛选（全部 / 无标签 / 各标签），也支持 `#tag` 搜索语法
- **一键粘贴**：选中片段后自动写入剪贴板 + 模拟 Ctrl+V 粘贴到呼出时的目标窗口
- **仅复制**：`Ctrl+Enter` 把选中片段写入剪贴板，不向目标窗口发送粘贴按键
- **快速新建**：`Ctrl+N` 从搜索窗打开完整编辑器，搜索词预填名称、剪贴板预填内容
- **快速选择**：`Alt+1..9` 直接使用前 9 条结果；常用片段可置顶
- **占位符模板**：按片段显式开启，支持 `{名称}` 填表、默认值和日期/时间/剪贴板内置变量
- **终端安全护栏**：多行内容粘贴到终端前要求确认

> 注意：粘贴片段会占据系统剪贴板（不恢复之前的内容）。粘贴过的片段留在剪贴板里，可以再次 Ctrl+V。
- **片段管理**：在设置页面添加、编辑、删除片段
- **批量导入**：PowerShell 历史、VS Code snippets、Espanso 配置
- **Git 多设备同步**：自动 commit/push/pull、同步状态提示和单条片段历史恢复；命令超时且不会弹出交互式凭据请求
- **深色模式、单实例、开机自启和自动更新检查**
- **系统托盘常驻**：后台运行，随时响应

竞品对比和后续产品路线见 [2026-07 竞品分析](./docs/product/competitive-analysis-2026-07.md)。

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

当前稳定版本：v0.1.25

## 参与维护

版本规划见 [plan.md](plan.md)，Issue 优先级、质量门禁、Windows 验收和发布闭环见 [维护与迭代手册](docs/maintenance.md)。

## License

MIT
