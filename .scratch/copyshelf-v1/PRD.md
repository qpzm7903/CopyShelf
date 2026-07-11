Status: ready-for-agent

# PRD: CopyShelf — Windows 片段启动器

> 术语以根目录 `CONTEXT.md` 为准：核心实体统一叫**片段（Snippet）**，不叫指令/命令。
> 2026-07-11 grilling 会话修订：定位收窄、数据模型拆分（ADR-0001）、粘贴焦点链路、同步时机等。

## Problem Statement

常用的文本片段（Git 命令、代码片段、LLM prompt、回复话术等）散落在笔记、聊天记录、终端历史里，每次要用都要翻找、切窗口、复制。用户需要一个工具把这些片段集中管理，做到一键呼出、快速搜索、频率排序、选中即粘贴，并通过 Git 在多台 Windows 设备间同步片段定义。

**定位**：片段启动器（snippet launcher）。**不是**剪贴板历史工具——不捕获系统剪贴板历史，永远不做。

## Solution

一个 Windows 原生 Flutter 桌面应用，常驻系统托盘，通过快捷键（默认 `Ctrl+Alt+V`）呼出一个类 Spotlight 的搜索框。用户输入关键词过滤片段，选中后写入剪贴板并模拟 `Ctrl+V` 粘贴到**目标窗口**（呼出快捷键那一刻的前台窗口）。片段定义存储在本地 `snippets.json`，通过 Git 同步；使用统计存本地 `stats.json`，不同步（ADR-0001）。

## User Stories

1. 作为用户，我想按一个快捷键就呼出搜索框，以便快速访问我的片段列表
2. 作为用户，我想在搜索框中输入关键词实时过滤片段，以便在大批片段中快速找到目标
3. 作为用户，我想选中一条片段后自动粘贴到目标窗口，以便减少操作步骤
4. 作为用户，我想看到一个按本机使用频率降序排列的片段列表，以便最常用的片段始终在最前面
5. 作为用户，我想在 UI 中添加一条新片段，以便不离开工具就能扩充片段库
6. 作为用户，我想在 UI 中编辑一条已有片段的名称、内容、描述或标签，以便随时更新
7. 作为用户，我想在 UI 中删除一条不再需要的片段，以便保持片段库整洁
8. 作为用户，我想在设置中更改数据存储目录，以便把片段文件放在我习惯的位置
9. 作为用户，我想在设置中配置 Git 远程仓库地址，以便在多设备间同步片段定义
10. 作为用户，我希望每次增删改片段后工具自动 commit + push，启动时自动 pull，以便无需手动操作 Git
11. 作为用户，当 Git 同步出现冲突时，我希望工具给出清晰提示让我手动解决，以便在冲突场景下不会丢失数据
12. 作为用户，我想工具开机自启并常驻系统托盘，以便随时可用
13. 作为用户，我想右键托盘菜单退出应用；主窗口点 X 只是隐藏到托盘，不退出进程
14. 作为用户，我想在设置中自定义快捷键，以便避免和其他软件的快捷键冲突
15. 作为用户，我希望首次启动时零配置即可使用，以便最快上手
16. 作为用户，我想在设置中点「立即同步」手动拉取远端改动，以便不重启就拿到另一台设备新增的片段

## Implementation Decisions

### 技术栈

- **框架**: Flutter（仅 Windows 平台）
- **状态管理**: Provider
- **本地存储**: `shared_preferences`（设置）/ JSON 文件（片段定义、使用统计）
- **窗口管理**: `window_manager`
- **系统托盘**: `tray_manager`（与 window_manager 同生态，维护更活跃）
- **全局快捷键**: `win32` 包（RegisterHotKey + Isolate 消息循环，已实现）
- **粘贴实现**: `win32` 包纯 Dart 调用（剪贴板写入 + SendInput 模拟 `Ctrl+V`）
- **拼音匹配**: `lpinyin` 或同类 Dart 库

### 架构

- `models/` — 数据模型，with `fromJson`/`toJson`
- `providers/` — 状态管理，继承 `ChangeNotifier`
- `services/` — 业务逻辑（存储、Git、粘贴、快捷键）
- `pages/` — UI 页面
- `theme/` — 主题
- `utils/` — 常量

核心实体从 `Command` 更名为 `Snippet`（类名、Provider、文件名、测试一并改）。

### 数据格式（ADR-0001：定义与统计分离）

```
snippets.json        ← Git 同步，仅增删改时 commit + push
[
  {
    "id": "uuid",
    "name": "git amend",
    "content": "git commit --amend --no-edit",
    "description": "快速修改上次提交",
    "tags": ["git"],
    "createdAt": "2026-07-01T10:00:00Z"
  }
]

stats.json           ← 本地文件，加入 .gitignore，粘贴时更新
{
  "<snippet-id>": { "frequency": 42, "lastUsedAt": "2026-07-04T12:00:00Z" }
}
```

`content` 是纯文本字符串，可多行（命令、LLM prompt 均可）。

### 粘贴链路（核心时序）

1. 快捷键触发时，**先 `GetForegroundWindow()` 记录目标窗口 HWND**，再 show + focus 搜索窗口；
2. 选中片段后：隐藏 CopyShelf 窗口 → `SetForegroundWindow(目标 HWND)` → 短暂延迟（约 50ms，等焦点切换完成）→ 写剪贴板 → `SendInput` 模拟 Ctrl+V；
3. 目标窗口已失效（HWND 无效）时降级：只写剪贴板，托盘气泡提示「已复制」。

**明确的产品行为**：粘贴片段会占据系统剪贴板，不恢复原有内容（README 说明）。全格式剪贴板恢复留作 v2 候选（设置项、默认关闭）。

### 搜索与排序

- 无搜索词时，按本机使用统计排序：frequency 降序，其次 lastUsedAt 降序；
- 有搜索词时，对 `name` / `description` / `tags` 做**关键词匹配**（子串匹配；中文字段额外支持全拼与首字母拼音命中），结果同样按频率排序；
- 不做 fuzzy 子序列匹配（v0.2+ 候选）。

### Git 同步

- 数据目录内 `git init`（如果尚无 `.git`）
- 增删改片段：自动 commit（消息如 `update snippets: add "git amend"`，数据仓库不用 conventional-commit 前缀）
- 每次 push 前先 `git pull --rebase`；应用启动时也 pull 一次
- 粘贴**不触发**任何 Git 操作（只写本地 stats.json）
- 设置页提供「立即同步」按钮手动 pull
- 冲突时：弹窗提示用户手动处理，不阻塞本地编辑

### 窗口生命周期

- 搜索窗口**失焦即自动隐藏**（点击别处 / Alt+Tab 离开），不抢焦点回来
- 主窗口点 X = 隐藏到托盘；退出仅通过托盘右键菜单
- 快捷键在窗口可见时按下 = 隐藏（toggle）

### 首次启动

- 默认数据目录：`%USERPROFILE%\.copyshelf`
- 零配置启动，直接可用
- 设置页面可修改数据目录和 Git 远程地址（均为本机设置，不随 Git 同步）

### 快捷键

- 默认 `Ctrl+Alt+V`
- 设置中可自定义修改

### 主题

- 中文审美主题风格（去阴影、灰底白卡、细线条）
- Windows 默认字体 `Microsoft YaHei UI`

## Testing Decisions

### 测试原则

只测试外部行为，不测试实现细节。关注状态变更后 UI 应观察到的数据变化是否符合预期。

### 测试切入点（Seam）

集中在一个 seam：**`SnippetProvider`**（原 CommandProvider）。通过注入 mock 的存储与统计服务，覆盖：

- 添加片段后列表是否更新
- 编辑片段后内容是否变更
- 删除片段后列表是否减少
- 关键词匹配是否按 name/description/tags 命中（含拼音用例）
- 使用片段后本机 frequency 和 lastUsedAt 是否更新（且不触发 Git 同步）
- 排序是否符合（频率优先，然后时间优先）
- 默认初始化时是否加载已有数据
- 状态更新使用不可变模式（copyWith 生成新对象，不原地修改）

粘贴焦点链路（GetForegroundWindow/SetForegroundWindow/SendInput）无法单元测试，靠手动验收清单覆盖。

### Prior art

沿袭 `test/models_test.dart`、`test/utils_test.dart` 的风格：纯 Dart 测试，不依赖 Flutter Widget 测试框架。

## Out of Scope

- 系统剪贴板历史纪录管理（**永远不做**——定位是片段启动器，不是剪贴板工具）
- 模板占位符/变量填空（v2 候选；当前 content 为纯字符串，格式天然兼容将来加占位符语法）
- Fuzzy 子序列匹配（v0.2+ 候选）
- 粘贴后恢复原剪贴板内容（v2 候选，设置项、默认关闭）
- 富文本或格式化粘贴（纯文本即可）
- 跨平台支持（仅 Windows）
- 自动解决 Git 冲突
- 使用统计跨设备同步（ADR-0001，各设备独立统计）
- 加密或密码保护
- 云同步服务（Git 已覆盖多设备同步需求）
- 片段分类/分组的可视化（tags 以文本标签形式展示，不提供树形分类 UI）

## Further Notes

- 个人效率工具，面向开发者/重度文本操作用户；片段内容以命令为主，兼有 LLM prompt 与中文话术
- 产品理念是「零摩擦」：快捷键按 → 打字搜索 → 回车粘贴，三步完成；任何给主流程加步骤/加网络 IO 的设计默认拒绝
- 第一个版本从 MVP 起步，不追求一次性做完所有功能
