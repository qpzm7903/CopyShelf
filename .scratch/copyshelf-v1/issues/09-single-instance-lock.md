Status: done (v0.1.4)

# 09: 单实例锁（localhost socket 方案）

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.4

## What was built

- `lib/services/single_instance_service.dart`：绑定 127.0.0.1:48632 即为持锁；
  次实例 `notifyExisting` 发送 `copyshelf-wake` 指令后 `exit(0)`；
  首实例收到指令呼出并聚焦搜索窗（不同于 toggle，不会把可见窗口藏起来）。
- 方案评审记录：排期评审 blocker 意见把原「命名互斥量 + FindWindow/PostMessage」
  方案替换为 socket 方案——全链路在 macOS/测试中可真实覆盖，无 win32 依赖。
- 托盘退出时释放锁端口。
- 抢锁失败且 notify 也失败（端口被外部程序占用）时次实例仍退出——极端场景，
  指令带 `copyshelf-` 前缀避免误触发外部程序。

## Acceptance criteria

- [x] 真实 socket 集成测试 6 例：抢锁成功 / 端口占用检测 / wake 唤醒回调 /
      无监听者 notify 返回 false / 垃圾数据不触发 / dispose 后端口可复用
- [x] 全部 73 测试通过，`flutter analyze` 零 error/warning
