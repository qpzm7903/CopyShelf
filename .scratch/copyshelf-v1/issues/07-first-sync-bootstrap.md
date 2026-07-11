Status: done (v0.1.6)

# 07: 第二台设备首次同步的引导流程

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

在 issue 04 的集成测试中发现：全新设备上应用会先 `git init` 并提交 scaffold（`[]` 的 snippets.json），之后用户配置远端再同步时，本地历史与远端不相关，且双方都"添加"了 snippets.json，首次 pull --rebase 必然产生 add/add 冲突——对每一台新增设备都是必踩的坑。

期望行为：配置 Git 远程地址时，若远端已有数据且本地仍是未使用过的 scaffold（片段列表为空、只有 init commit），自动以远端为准完成首次同步，用户无感知。本地已有真实片段而远端也有数据时，才走冲突提示流程。

## Acceptance criteria

- [ ] 模拟场景（集成测试）：设备 A 已推送若干片段 → 全新设备 B 零配置启动 → 配置远端 → 同步后 B 直接看到 A 的片段，无冲突提示
- [ ] 本地已有真实片段 + 远端有不同数据时，不静默覆盖任何一方，给出清晰提示
- [ ] 现有 38 个测试不回归

## Blocked by

- 04 (`04-git-sync-timing.md`)
