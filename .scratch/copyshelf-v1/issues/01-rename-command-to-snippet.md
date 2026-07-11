Status: ready-for-agent

# 01: 全库更名 Command → Snippet（prefactor）

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

把核心实体的统一语言从「指令（Command）」改为「片段（Snippet）」，贯穿全部层：数据模型、状态管理 Provider、服务层引用、UI 文案（搜索框占位符、空状态、设置页、托盘菜单）、测试、数据文件名（`commands.json` → `snippets.json`）。术语定义见根目录 `CONTEXT.md`。

这是一次纯更名 prefactor，不改任何行为——为后续切片铺路，让它们的 diff 保持干净。

无存量用户与存量数据，不需要写迁移逻辑；本机已有 `commands.json` 的开发环境手动重命名即可。

## Acceptance criteria

- [ ] 代码中不再出现 `Command` / `command` 作为核心实体命名（Git 相关的 "commit" 等无关词除外）
- [ ] 数据文件读写指向 `snippets.json`
- [ ] 所有 UI 可见文案使用「片段」，不出现「指令」
- [ ] `flutter analyze` 无错误，现有测试全部通过（测试中的命名同步更新）
- [ ] 应用可正常启动并加载片段列表

## Blocked by

None - can start immediately
