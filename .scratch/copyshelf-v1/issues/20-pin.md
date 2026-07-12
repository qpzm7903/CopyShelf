Status: done (v0.1.16)

# 20: 片段置顶（pin）

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.16

## What was built

- SnippetStats 加 pinned（本地状态，不同步 ADR-0001）；未置顶不写字段省空间；toJson/fromJson 往返。
- Provider.togglePin（切换 + 持久化 stats.json，不触发 Git）/ isPinned。
- 排序：置顶项恒排最前，置顶组内仍按 frecency；取消置顶回归 frecency。
- 搜索窗每行右侧 pin 图标（实心=已置顶/描边=未置顶），点击切换。

## Acceptance criteria

- [x] SnippetStats 单元测试 3 例（切换/往返/未置顶不写字段）
- [x] Provider 排序单元测试 6 例（置顶最前/组内 frecency/取消回归/持久化/不触发 Git）
- [x] 全部 208 测试通过，`flutter analyze` 零 error/warning
