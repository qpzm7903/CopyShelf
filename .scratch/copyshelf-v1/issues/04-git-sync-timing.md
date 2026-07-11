Status: done

# 04: Git 同步时机——push 前 rebase + 手动立即同步

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

常驻托盘应用可能数周不重启，只靠启动时 pull 会让本地落后远端、push 被拒。按 grilling 会话决议（PRD「Git 同步」一节）补齐同步时机：

- 每次 push 前先 `git pull --rebase`（增删改片段触发的自动 push 均适用）；
- 应用启动时 pull 一次（保持现有行为）；
- 设置页新增「立即同步」按钮：手动触发 pull，成功后刷新片段列表，失败给出可读的错误提示；
- rebase 冲突时：弹窗提示用户手动处理（指出数据目录路径），**不阻塞本地编辑**——本地片段的增删改和粘贴照常工作。

粘贴不触发任何 Git 操作（02 已保证，此处不要回归）。

## Acceptance criteria

- [ ] 用两个本地 clone 模拟双设备：A 添加片段并 push 后，B 直接编辑另一条片段，B 的 push 成功且两边最终收敛（B 先 rebase 再 push）
- [ ] 双方修改**同一条**片段造成冲突时：弹窗提示，本地列表仍可增删改和粘贴
- [ ] 设置页「立即同步」按钮：远端有新片段时点击后列表立即出现新片段；无网络时报错不崩溃
- [ ] Provider/GitService 测试覆盖 push 前 rebase 的调用顺序与冲突时的错误上报

## Blocked by

- 02 (`02-split-stats-from-definitions.md`)

## Comments

- 2026-07-11: 完成。38 个测试全过，其中 3 个是真实 git 双 clone 集成测试（交叉改动收敛 / 同行冲突后本地仍可编辑 / 空远端 pull 不报错）。
- 顺带修复：snippets.json 改为多行缩进 JSON——原单行格式下任何双端并发编辑必然文本冲突。
- 发现新问题，另立工单 07：第二台全新设备（本地已有 init commit）配置远端后首次 pull 会因不相关历史/scaffold 文件产生 add/add 冲突。
