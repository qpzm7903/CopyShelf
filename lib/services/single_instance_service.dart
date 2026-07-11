import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 单实例锁（localhost socket 方案）
///
/// 首实例绑定 127.0.0.1 固定端口即为持锁；再次启动的进程连接该端口
/// 发送 wake 指令后退出，首实例收到指令后呼出搜索窗。
/// 相比 Windows 命名互斥量方案，全链路可在任意平台真实测试。
class SingleInstanceService {
  /// CopyShelf 固定锁端口（仅监听 loopback，不对外暴露）
  static const int defaultPort = 48632;

  /// 唤醒指令；带应用前缀避免其他程序端口冲突时误触发
  static const String wakeCommand = 'copyshelf-wake';

  static const Duration _connectTimeout = Duration(seconds: 1);

  ServerSocket? _server;

  /// 成功抢锁后实际监听的端口（未抢到锁为 null）
  int? get port => _server?.port;

  /// 尝试获得单实例锁。
  ///
  /// 成功返回 true 并开始监听 [onWake] 唤醒指令；
  /// 端口已被占用（通常是已有实例在运行）返回 false。
  Future<bool> tryAcquire({
    int port = defaultPort,
    required Future<void> Function() onWake,
  }) async {
    try {
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      return false;
    }

    _server!.listen((client) {
      client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim() == wakeCommand) {
            onWake();
          }
        },
        onError: (_) {},
        cancelOnError: true,
      );
    });
    return true;
  }

  /// 通知已在运行的实例唤醒（次实例调用后应自行退出）。
  ///
  /// 返回 true 表示指令送达；连接失败（无实例监听）返回 false。
  static Future<bool> notifyExisting({int port = defaultPort}) async {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: _connectTimeout,
      );
      socket.write('$wakeCommand\n');
      await socket.flush();
      await socket.close();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// 释放锁（关闭监听端口）
  Future<void> dispose() async {
    await _server?.close();
    _server = null;
  }
}
