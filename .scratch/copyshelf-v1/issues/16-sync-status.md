Status: done (v0.1.12)

# 16: Git 同步状态可视化 + 注册表健壮性

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.12

## What was built

- `models/sync_status.dart`：SyncState(idle/syncing/ok/error) + SyncStatus 不可变快照（含 message、lastSuccessAt）。
- SnippetProvider 暴露 syncStatus，init/syncNow/_persistAndSync 三入口驱动状态机；
  未配远端时不误报「已同步」（_hasRemote 门控，读偏好失败保守视为未配置）。
- `widgets/sync_indicator.dart`：主窗 footer 常驻指示（idle 隐藏 / syncing 转圈 / ok 绿点+相对时间 / error 红色可 hover 详情）。
- 设置页「数据与同步」新增最近失败详情面板（可选中复制 stderr）。

## 附带修复（bug 审查里程碑 1 · MEDIUM，同时修复 CI 红）

- 注册表 openPath 在全新用户 profile 下 HKCU\...\Run 键不存在时抛 0x80070002 未被捕获，
  导致设置页/自启读取崩溃、Windows CI 常红。修复：read/delete 用 _openExisting 容忍键缺失返回 null，
  write 改用 createKey 幂等创建键；设置页 _readAutostartSafely 兜底。

## Acceptance criteria

- [x] 状态机单元测试 8 例（idle/syncing→ok/error、保留成功时间、未配远端不误报、通知监听者）
- [x] SyncIndicator widget 测试 3 例（idle 隐藏 / ok / error）
- [x] 全部 154 测试通过，`flutter analyze` 零 error/warning
