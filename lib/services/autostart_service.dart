import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 开机自启服务
///
/// 通过 HKCU\Software\Microsoft\Windows\CurrentVersion\Run 注册表项实现，
/// 用户 hive 无需管理员权限。注册表本身即持久化状态，不再额外存偏好。

/// Run 键值的存取抽象（测试注入内存实现，运行时用 [WindowsRunKeyStore]）
abstract class RunKeyStore {
  /// 读取自启命令；未设置返回 null
  String? read();

  void write(String command);

  void delete();
}

/// 开机自启的注册命令：路径含空格时必须加引号，否则 Windows 会截断解析
String formatRunCommand(String exePath) =>
    exePath.contains(' ') ? '"$exePath"' : exePath;

class AutostartService {
  final RunKeyStore _store;

  AutostartService(this._store);

  bool get isEnabled => _store.read() != null;

  /// 开启自启；[exePath] 默认取当前可执行文件路径
  void enable({String? exePath}) {
    _store.write(formatRunCommand(exePath ?? Platform.resolvedExecutable));
  }

  void disable() => _store.delete();
}

/// 真实注册表实现（仅 Windows 可用）
class WindowsRunKeyStore implements RunKeyStore {
  static const String _runKeyPath =
      r'Software\Microsoft\Windows\CurrentVersion\Run';

  /// 注册表值名；测试时传临时名避免污染真实配置
  final String valueName;

  WindowsRunKeyStore({this.valueName = 'CopyShelf'});

  /// 打开 Run 键；键不存在（全新用户 profile 下 HKCU\...\Run 可能尚未创建）
  /// 或权限受限时返回 null，由调用方按「未启用」处理。
  RegistryKey? _openExisting() {
    try {
      return Registry.openPath(
        RegistryHive.currentUser,
        path: _runKeyPath,
        desiredAccessRights: AccessRights.allAccess,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String? read() {
    final key = _openExisting();
    if (key == null) return null;
    try {
      final value = key.getValue(valueName);
      if (value is StringValue) return value.value;
      return null;
    } catch (_) {
      // 值不存在或 win32 GetLastError 残留触发的异常：未启用自启，属正常状态
      return null;
    } finally {
      key.close();
    }
  }

  @override
  void write(String command) {
    // createKey 在键不存在时创建（幂等），覆盖全新 profile 场景
    final key = Registry.currentUser.createKey(_runKeyPath);
    try {
      key.createValue(RegistryValue.string(valueName, command));
    } finally {
      key.close();
    }
  }

  @override
  void delete() {
    final key = _openExisting();
    if (key == null) return;
    try {
      key.deleteValue(valueName);
    } catch (_) {
      // 值本就不存在：视为已删除
    } finally {
      key.close();
    }
  }
}
