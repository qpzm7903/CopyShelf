Status: ready-for-agent

# 02: 数据拆分——使用统计本地化（ADR-0001）

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

按 ADR-0001（`docs/adr/0001-usage-stats-not-synced.md`）把片段数据拆成两个文件：

- **片段定义**（name / content / description / tags / createdAt）→ `snippets.json`，Git 同步，仅增删改时 commit + push；
- **使用统计**（frequency / lastUsedAt，按片段 id 索引）→ `stats.json`，写入数据目录的 `.gitignore`，粘贴时只更新本地统计，**不触发任何 Git 操作**。

排序行为不变：frequency 降序，其次 lastUsedAt 降序（现在是本机统计）。定义文件里不存在统计的片段按 frequency=0 处理；统计里的孤儿 id（片段已在别的设备删除）静默忽略。

顺带两个清理：统计更新改为不可变模式（生成新对象，不原地 `frequency++`）；数据仓库的 commit 消息去掉 conventional-commit 前缀（如 `update snippets: add "git amend"`，粘贴不再产生 commit）。

数据格式见 PRD「数据格式」一节（来自 grilling 会话决议）：

```
stats.json
{ "<snippet-id>": { "frequency": 42, "lastUsedAt": "2026-07-04T12:00:00Z" } }
```

## Acceptance criteria

- [ ] 粘贴片段 10 次：`stats.json` 更新 10 次，Git 历史零新增 commit，无网络请求
- [ ] 增/删/改片段各产生恰好一次 commit + push，且 `snippets.json` 中不含 frequency/lastUsedAt 字段
- [ ] `stats.json` 在数据目录的 `.gitignore` 中，`git status` 不显示它
- [ ] 远端同步来的新片段（本地无统计）正常显示且排在频率序末尾
- [ ] Provider 测试覆盖：使用片段后统计更新且不触发 Git；统计更新为不可变操作
- [ ] 排序测试通过：频率优先、时间次之

## Blocked by

- 01 (`01-rename-command-to-snippet.md`)
