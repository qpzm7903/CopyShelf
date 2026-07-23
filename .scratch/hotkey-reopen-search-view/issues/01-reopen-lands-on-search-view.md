Status: released (v0.2.1, 2026-07-23; Windows 实机验收待补)

# 01: 快捷键/托盘/唤醒呼出窗口时总是回到搜索界面

## What was built

- `SnippetProvider.showSearch()` 复位 `_isSettingsOpen = false`，并自增
  `searchInvocation` 呼出计数（新增 getter），三个呼出入口都经此收敛。
- `HomePage` 监听 provider，`searchInvocation` 变化即在帧回调里
  `popUntil(isFirst)`，把残留的片段编辑器等 push 路由出栈；设置页由 build 复位。
- 测试：`snippet_provider_test.dart` 单测覆盖 showSearch 复位设置标志；
  新增 `reopen_search_view_test.dart` widget 测试覆盖编辑器出栈与从设置页返回。

## Parent

用户反馈：「我希望每次使用快捷键打开的时候，都应该在搜索界面」。

## What to build

无论窗口上次被留在什么视图，按下全局快捷键（以及托盘左键切换、单实例唤醒）
呼出窗口后，看到的都必须是**搜索界面**：搜索词为空、标签过滤回到「全部」。

当前有两条路径会让呼出后停留在非搜索视图，都要修掉：

1. **设置页残留**：在设置页点 ✕ 只隐藏窗口、不关闭设置（`onWindowClose`
   无条件 `hide`），下次呼出仍渲染设置页。`showSearch()` 目前清空搜索词/标签/提示，
   但没有复位 `isSettingsOpen`。
2. **片段编辑器残留**：片段编辑器是 push 到 Navigator 的路由（不是 Provider 标志位），
   编辑器打开时点 ✕ 会带着该路由隐藏窗口，下次呼出编辑器仍压在搜索界面之上。
   Provider 无 `Navigator`，这条需要在 widget 层随窗口显示时出栈处理。

三个呼出入口（快捷键 toggle、托盘 toggle、单实例 wake）都已经调用
`showSearch()`，把「复位到搜索视图」收敛到这一个入口即可覆盖三者；编辑器路由出栈
需另在 widget 层挂钩窗口显示事件。实现细节自行判断，勿在本票据里钉死文件/代码。

## Blocked by

None — can start immediately.

## Acceptance criteria

- [x] 打开设置页 → 点 ✕ 隐藏 → 按快捷键呼出 → 看到搜索界面，而非设置页
- [x] 打开片段编辑器 → 点 ✕ 隐藏 → 按快捷键呼出 → 看到搜索界面，编辑器不再压在上层
- [x] 呼出后搜索词为空、标签过滤为「全部」（沿用现有 `showSearch()` 语义）
- [x] 托盘左键切换与单实例唤醒两条入口同样回到搜索界面（三者共用 `showSearch()`）
- [x] 单元测试覆盖 `showSearch()` 复位设置标志；widget 测试覆盖编辑器路由被呼出流程出栈
- [x] `flutter analyze` 零 error/warning，测试全绿（303 通过，2 跳过）

## 待实机验证（Windows）

- [ ] 设置页 → ✕ → 快捷键，落在搜索界面
- [ ] 编辑器 → ✕ → 快捷键，落在搜索界面且可正常输入搜索
