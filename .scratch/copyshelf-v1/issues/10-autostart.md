Status: done (v0.1.5)

# 10: 开机自启

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.5

## What was built

- `lib/services/autostart_service.dart`：
  - `RunKeyStore` 抽象（测试注入内存实现）+ `WindowsRunKeyStore` 真实实现
    （win32_registry 包，HKCU\Software\Microsoft\Windows\CurrentVersion\Run，
    用户 hive 无需管理员权限）。
  - `formatRunCommand`：exe 路径含空格时加引号，防 Windows 截断解析。
  - 注册表即持久化状态，不重复存 shared_preferences。
- 设置页新增「常规」分区 + 开机自启开关（仅 Windows 显示）。
- 新增依赖 `win32_registry: ^2.1.0`。

## Acceptance criteria

- [x] mock 三态往返测试（初始未启用 / enable 写入带引号路径 / disable 清除）
- [x] 引号规则单元测试（含空格加引号、无空格不加）
- [x] `Platform.isWindows` 守卫的真实注册表写→读→删往返集成测试
      （临时值名 CopyShelfTest_<pid>，macOS skip，Windows CI 执行）
- [x] 全部 78 测试通过（77 过 + 1 平台 skip），`flutter analyze` 零 error/warning

## 待实机验证（Windows）

- [ ] 开关打开后注销重登，CopyShelf 自动启动进托盘
