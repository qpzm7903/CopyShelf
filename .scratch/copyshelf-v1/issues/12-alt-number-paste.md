Status: done (v0.1.8)

# 12: Alt+1..9 直达粘贴

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.8

## What was built

- 搜索窗内按 Alt+1..9 直接粘贴列表（当前排序/过滤下）第 N 项，无需方向键移动。
- 列表前 9 项渲染序号角标（选中态高亮），第 10 项起不显示。
- 列表不足 N 项时 Alt+N 无动作；不按 Alt 的数字键正常进入搜索输入。

## Acceptance criteria

- [x] widget 测试 5 例：Alt+3 / Alt+1 / Alt+9 粘贴对应项、越界不动作、
      无 Alt 不触发、角标渲染边界（1、9 有，10 无）
- [x] 全部 95 测试通过，`flutter analyze` 零 error/warning
