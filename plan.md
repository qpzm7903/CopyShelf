# CopyShelf — 剪贴板指令管理器

## 长期目标

构建一个 Windows 桌面应用，通过快捷键快速搜索并粘贴用户配置的文本指令/命令片段，支持 Git 多设备同步。

## 中期目标

- [x] 项目骨架搭建（Flutter、Provider 分层、Windows 平台通道）
- [x] 系统托盘常驻 + 全局快捷键 `Ctrl+Alt+V` 呼出
- [x] 搜索框 UI（类 Spotlight 风格）
- [x] 片段 CRUD（UI 增删改）
- [x] 频率排序 + 关键词搜索（含拼音匹配）
- [x] 粘贴到目标窗口（win32 目标窗口捕获/归还 + SendInput Ctrl+V）
- [x] Git 自动同步（增删改 commit/push，push 前 rebase；统计本地化见 ADR-0001）
- [x] GitHub Actions CI 构建

---

## 版本历史

### v0.1.0 (MINOR) — 当前开发版本
- **状态**: 开发中 🔧
- **目标**: MVP — 基础搜索 + CRUD + 粘贴 + Git 同步
- **任务**:
  - [x] 项目骨架搭建
  - [x] 数据模型（Snippet + SnippetStats，定义/统计分离见 ADR-0001）
  - [x] 状态管理（SnippetProvider）
  - [x] 存储服务（StorageService — snippets.json + 本地 stats.json）
  - [x] Git 同步服务（GitService — 增删改 commit/push，push 前 rebase）
  - [x] 粘贴链路（PasteService — 目标窗口捕获/归还 + SendInput）
  - [x] 搜索 UI（SearchOverlay — 类 Spotlight，含拼音匹配）
  - [x] 设置页面（SettingsPage — 数据目录、Git、CRUD、立即同步）
  - [x] 主题（AppTheme — 国内审美风格）
  - [x] Windows 原生 runner 文件
  - [x] CI 构建配置（GitHub Actions）
  - [x] 测试（Model + SnippetProvider + GitService 双设备集成）
  - [x] 系统托盘集成（tray_manager：左键切换、右键菜单设置/退出）
  - [x] 窗口生命周期（失焦隐藏、关闭到托盘）
  - [ ] Windows 实机联调验收（见各 issue 的手动验收清单）
