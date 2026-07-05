Status: ready-for-agent

# PRD: CopyShelf — Windows 剪贴板指令管理器

## Problem Statement

Windows 剪贴板在多次复制后，旧内容会被覆盖丢失。用户需要一个工具来管理和快速调用常用的文本指令/命令片段（如 Git 命令模板、回复话术、代码片段等）。这些指令是用户手动配置的，独立于系统剪贴板历史，需要做到一键呼出、快速搜索、频率排序，并能通过 Git 在多个 Windows 设备间同步。

## Solution

一个 Windows 原生 Flutter 桌面应用，常驻系统托盘，通过快捷键（默认 `Ctrl+Alt+V`）呼出一个类 Spotlight 的搜索框。用户在搜索框中输入关键词过滤指令，选中后自动复制内容并模拟 `Ctrl+V` 粘贴到前台窗口。指令数据存储在本地 `commands.json` 文件中，通过 Git 自动同步到多个设备。

## User Stories

1. 作为用户，我想按一个快捷键就呼出搜索框，以便快速访问我的指令列表
2. 作为用户，我想在搜索框中输入关键词实时过滤指令，以便在大批指令中快速找到目标
3. 作为用户，我想选中一条指令后自动粘贴到当前活动的窗口，以便减少操作步骤
4. 作为用户，我想看到一个按使用频率降序排列的指令列表，以便最常用的指令始终在最前面
5. 作为用户，我想在 UI 中添加一条新指令，以便不离开工具就能扩充指令库
6. 作为用户，我想在 UI 中编辑一条已有指令的名称、内容、描述或标签，以便随时更新
7. 作为用户，我想在 UI 中删除一条不再需要的指令，以便保持指令库整洁
8. 作为用户，我想在设置中更改数据存储目录，以便把指令文件放在我习惯的位置
9. 作为用户，我想在设置中配置 Git 远程仓库地址，以便在多设备间同步指令
10. 作为用户，我希望每次增删改指令后工具自动 commit，启动时自动从远端 pull，每次 commit 后自动 push，以便无需手动操作 Git
11. 作为用户，当 Git 同步出现冲突时，我希望工具给出清晰提示让我手动解决，以便在冲突场景下不会丢失数据
12. 作为用户，我想工具开机自启并常驻系统托盘，以便随时可用
13. 作为用户，我想右键托盘菜单退出应用，以便需要时完全关闭程序
14. 作为用户，我想在设置中自定义快捷键，以便避免和其他软件的快捷键冲突
15. 作为用户，我希望首次启动时零配置即可使用，以便最快上手

## Implementation Decisions

### 技术栈

- **框架**: Flutter（仅 Windows 平台）
- **状态管理**: Provider（参考项目的风格）
- **本地存储**: `shared_preferences`（设置）/ JSON 文件（指令数据）
- **窗口管理**: `window_manager`
- **系统托盘**: `system_tray`
- **全局快捷键**: `hotkey_manager` 或 `win32` 平台通道
- **粘贴实现**: Flutter 平台通道（Method Channel）调用 Windows 原生 API，先写入系统剪贴板再模拟 `Ctrl+V`

### 架构

沿用参考项目的架构风格：

- `models/` — 数据模型，with `fromJson`/`toJson`
- `providers/` — 状态管理，继承 `ChangeNotifier`
- `services/` — 业务逻辑（存储、Git、粘贴）
- `pages/` — UI 页面
- `theme/` — 主题
- `utils/` — 常量

### 数据格式

```
commands.json
[
  {
    "id": "uuid",
    "name": "git amend",
    "content": "git commit --amend --no-edit",
    "description": "快速修改上次提交",
    "tags": ["git"],
    "frequency": 42,
    "lastUsedAt": "2026-07-04T12:00:00Z",
    "createdAt": "2026-07-01T10:00:00Z"
  }
]
```

### UI 行为

- 搜索框无搜索词时，指令按 `(frequency, lastUsedAt)` 综合降序排列
- 输入搜索词时，对 `name` / `description` / `tags` 做模糊匹配，匹配结果再按频率排序
- 选中指令后：写入系统剪贴板 → 模拟 `Ctrl+V` → 自动隐藏搜索框

### Git 同步

- 数据目录内 `git init`（如果尚无 `.git`）
- 每次增删改指令：自动 commit（消息如 "update commands"）
- 每次 commit 后：自动 `git push`
- 应用启动时：自动 `git pull --rebase`
- 冲突时：弹窗提示用户手动处理，不阻塞本地编辑

### 首次启动

- 默认数据目录：`%USERPROFILE%\.copyshelf`
- 零配置启动，直接可用
- 设置页面可修改数据目录和 Git 远程地址

### 快捷键

- 默认 `Ctrl+Alt+V`
- 设置中可自定义修改

### 主题

- 参考项目的中文审美主题风格（去阴影、灰底白卡、细线条）
- Windows 默认字体 `Microsoft YaHei UI`

## Testing Decisions

### 测试原则

只测试外部行为，不测试实现细节。关注的不是某个方法被调用了，而是状态变更后 UI 应观察到的数据变化是否符合预期。

### 测试切入点（Seam）

集中在一个 seam：**`CommandProvider`**。通过注入 mock 的 `StorageService`，覆盖以下行为：

- 添加指令后列表是否更新
- 编辑指令后内容是否变更
- 删除指令后列表是否减少
- 搜索关键词过滤是否按 name/description/tags 匹配
- 使用指令后 frequency 和 lastUsedAt 是否递增
- 排序是否符合（频率优先，然后时间优先）
- 默认初始化时是否从 StorageService 加载已有数据

### Prior art

参考项目中有 `test/models_test.dart` 和 `test/utils_test.dart`，沿袭同样的测试风格：纯 Dart 测试，不依赖 Flutter Widget 测试框架。

## Out of Scope

- 系统剪贴板历史纪录管理（只管理用户配置的指令）
- 富文本或格式化粘贴（纯文本即可）
- 跨平台支持（仅 Windows）
- 自动解决 Git 冲突
- 加密或密码保护
- 云同步服务（Git 已覆盖多设备同步需求）
- 指令分类/分组的可视化（tags 以文本标签形式展示，不提供树形分类 UI）

## Further Notes

- 这是一个个人效率工具，面向开发者/重度的文本操作用户
- 产品理念是"零摩擦"：快捷键按 → 打字搜索 → 回车粘贴，三步完成
- 第一个版本从 MVP 起步，不追求一次性做完所有功能
