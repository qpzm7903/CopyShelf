Status: ready-for-agent

# 06: 拼音关键词匹配

## Parent

`.scratch/copyshelf-v1/PRD.md`

## What to build

搜索行为按 `CONTEXT.md` 的「关键词匹配」定义补齐拼音支持：搜索词对片段名称/描述/标签做子串匹配之外，中文字段额外支持**全拼**与**首字母缩写**命中——呼出搜索框后无需切输入法，敲 `huifu` 或 `hf` 即可命中「回复话术」。

引入 Dart 拼音库（如 `lpinyin`）做汉字→拼音转换。匹配仍是子串语义，**不做** fuzzy 子序列匹配（Out of Scope，v0.2+）。多音字按库的默认读音处理即可，不做多读音展开。

结果排序规则不变（频率优先、时间次之）。

## Acceptance criteria

- [ ] 名为「回复话术-催发货」的片段能被 `huifu`、`hf`、`回复` 三种输入命中
- [ ] 英文片段（如 `git amend`）的子串匹配行为不回归
- [ ] 纯英文/数字的名称不做拼音转换，无误命中（如搜 `hf` 不命中不含这些字母的英文名）
- [ ] Provider 测试覆盖：全拼命中、首字母命中、中英混合名称、tags 与 description 上的拼音命中
- [ ] 搜索在片段量 100+ 时无可感知卡顿（拼音串在片段加载时预计算，不在每次按键时转换）

## Blocked by

- 01 (`01-rename-command-to-snippet.md`)
