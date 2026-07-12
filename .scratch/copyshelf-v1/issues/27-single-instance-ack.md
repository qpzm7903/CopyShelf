Status: done (v0.1.23)

# 27: 单实例锁 ack 握手（修 bug-M1 HIGH）

## Parent

bug 审查里程碑 1 · HIGH：端口 48632 被无关程序占用时应用静默 exit(0)、永远打不开。

## What was built

- SingleInstanceService 加 ack 握手：首实例收到 wakeCommand 后回 `copyshelf-ack` 再唤醒；
  notifyExisting 只在读到 ack 才返回 true（确认对端确实是 CopyShelf）。
- main.dart 降级：notifyExisting 返回 false（陌生程序占端口/超时/无应答）时不再退出，
  降级为无锁正常启动，保证应用永远可用。

## Acceptance criteria

- [x] CopyShelf 实例回 ack → notifyExisting 返回 true
- [x] 陌生程序占端口只 accept 不回 ack → notifyExisting 返回 false
- [x] 原有 socket 集成测试不回归
- [x] 全部 261 测试通过，`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 另一程序占用 48632 时 CopyShelf 仍能启动
- [ ] 正常双开时唤醒已有实例
