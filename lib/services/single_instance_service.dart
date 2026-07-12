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

  /// 首实例对唤醒指令的应答；用于确认对端确实是 CopyShelf（而非碰巧占端口的程序）
  static const String ackResponse = 'copyshelf-ack';

  static const Duration _connectTimeout = Duration(seconds: 1);
  static const Duration _ackTimeout = Duration(seconds: 1);

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
            // 先回 ack 确认身份，再执行唤醒
            client.write('$ackResponse\n');
            client.flush().then((_) => client.close()).catchError((_) {});
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
  /// 只有收到 [ackResponse] 应答才返回 true——确认对端确实是 CopyShelf。
  /// 连接失败、超时、或对端是碰巧占端口的陌生程序（不回 ack）均返回 false，
  /// 让 main 据此降级为无锁正常启动，而不是静默退出。
  static Future<bool> notifyExisting({int port = defaultPort}) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: _connectTimeout,
      );
      socket.write('$wakeCommand\n');
      await socket.flush();

      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.trim() == ackResponse,
              orElse: () => '')
          .timeout(_ackTimeout, onTimeout: () => '');
      return response.trim() == ackResponse;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  /// 释放锁（关闭监听端口）
  Future<void> dispose() async {
    await _server?.close();
    _server = null;
  }
}
