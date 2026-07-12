Status: done (v0.1.13)

# 17: 片段历史回滚 + git 分支不一致修复

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.13

## What was built

- GitService.fileHistory（snippets.json 提交历史，短哈希+时间+信息，最新在前）
  与 snippetsAtCommit（取某提交的文件内容）。
- SnippetProvider.snippetHistory（按 id 抽取跨提交的版本，连续相同内容去重）
  与 restoreSnippet（只改该条 + 自动 commit/push）。
- 编辑页「历史」按钮（仅编辑模式）→ 历史列表对话框，选中把内容填回编辑器，
  点保存确认恢复（不立即写，用户可再改）。

## 附带修复（bug 审查里程碑 1 · MEDIUM）

- git 分支不一致静默失效：本地 master + 远端 main 时 pull 命中 "couldn't find remote ref"
  被当成功、各推各分支。修复：命中时查 _remoteDefaultBranch，非空远端返回可读错误提示对齐分支。

## Acceptance criteria

- [x] Provider 历史单元测试 5 例（抽取/去重/跳过缺失/恢复只改该条+同步/不存在 id 无操作）
- [x] 真实 git fileHistory/snippetsAtCommit 集成测试 3 例
- [x] 编辑页历史 UI widget 测试 3 例（新建无按钮/弹列表/选中填回）
- [x] git 分支不一致回归测试 2 例
- [x] 全部 167 测试通过，`flutter analyze` 零 error/warning
