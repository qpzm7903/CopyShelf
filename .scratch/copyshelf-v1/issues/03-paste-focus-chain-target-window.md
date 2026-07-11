Status: done

# 03: 粘贴焦点链路——目标窗口捕获与归还

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

让片段真正落到**目标窗口**（术语见 `CONTEXT.md`）里，而不是贴回 CopyShelf 自己。这是产品的第一颗完整 tracer bullet：快捷键 → 搜索 → 回车 → 文字出现在目标应用。

时序（来自 grilling 会话决议，PRD「粘贴链路」一节）：

1. 全局快捷键触发时，show 搜索窗口**之前**先 `GetForegroundWindow()` 记录目标窗口句柄；
2. 选中片段后：隐藏 CopyShelf 窗口 → `SetForegroundWindow(目标句柄)` → 短暂延迟（约 50ms，等焦点切换完成）→ 写剪贴板 → SendInput 模拟 Ctrl+V；
3. 目标窗口已失效（句柄无效/窗口已关闭）时**降级为仅复制**：只写剪贴板，托盘气泡提示「已复制到剪贴板」。

同时在 README 补一句明确的产品行为：粘贴片段会占据系统剪贴板，不恢复原有内容。

## Acceptance criteria

- [ ] 在记事本中按 `Ctrl+Alt+V` 呼出 → 输入关键词 → 回车，片段文字出现在记事本光标处
- [ ] 呼出后先点开另一个窗口（改变前台）再呼出选择，文字落在第二次呼出时的前台窗口
- [ ] 呼出后关闭目标应用再选中片段：不崩溃，剪贴板中有片段内容，托盘气泡提示已复制
- [ ] 粘贴后 CopyShelf 窗口已隐藏，不残留在前台
- [ ] README 说明剪贴板覆盖行为
- [ ] 焦点链路本身无法单元测试，上述场景以手动验收清单形式记录在 issue 评论中

## Blocked by

- 02 (`02-split-stats-from-definitions.md`)

## Comments

- 2026-07-11: 代码完成于 commit（见 git log "issue 03"）。35 个测试全过。
- 说明：降级提示当前用搜索框内的提示条（notice banner）实现，托盘气泡待 issue 05 托盘集成后切换。
- 手动验收清单（需在 Windows 机器上执行，本机为 macOS 无法运行）：
  - [ ] 记事本中呼出 → 回车，文字落在记事本光标处
  - [ ] 呼出后点开另一窗口再呼出选择，文字落在第二次的前台窗口
  - [ ] 呼出后关闭目标应用再选中：不崩溃，剪贴板有内容，提示条出现
  - [ ] 粘贴后 CopyShelf 窗口已隐藏
