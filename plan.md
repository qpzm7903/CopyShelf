# CopyShelf — 剪贴板指令管理器

## 长期目标

构建一个 Windows 桌面应用，通过快捷键快速搜索并粘贴用户配置的文本指令/命令片段，支持 Git 多设备同步。

## 中期目标

- [x] 项目骨架搭建（Flutter、Provider 分层、Windows 平台通道）
- [ ] 系统托盘常驻 + 全局快捷键 `Ctrl+Alt+V` 呼出
- [ ] 搜索框 UI（类 Spotlight 风格）
- [ ] 指令 CRUD（UI 增删改）
- [ ] 频率排序 + 关键词搜索
- [ ] 粘贴到前台窗口（Method Channel 模拟 Ctrl+V）
- [ ] Git 自动同步（commit/push/pull）
- [ ] GitHub Actions CI 构建

---

## 版本历史

### v0.1.0 (MINOR) — 当前开发版本
- **状态**: 开发中 🔧
- **目标**: MVP — 基础搜索 + CRUD + 粘贴 + Git 同步
- **任务**:
  - [x] 项目骨架搭建
  - [x] 数据模型（Command）
  - [x] 状态管理（CommandProvider）
  - [x] 存储服务（StorageService — JSON 文件读写）
  - [x] Git 同步服务（GitService — auto commit/push/pull）
  - [x] 粘贴平台通道（PasteService — Win32 API）
  - [x] 搜索 UI（SearchOverlay — 类 Spotlight）
  - [x] 设置页面（SettingsPage — 数据目录、Git、CRUD）
  - [x] 主题（AppTheme — 国内审美风格）
  - [x] Windows 原生 runner 文件
  - [x] CI 构建配置（GitHub Actions）
  - [x] 测试（Model + CommandProvider）
  - [ ] 系统托盘集成调试
  - [ ] 全局快捷键注册调试
