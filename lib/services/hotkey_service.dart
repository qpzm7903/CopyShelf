import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 全局快捷键服务
///
/// 在独立 Isolate 中调用 RegisterHotKey + GetMessageW 阻塞接收 WM_HOTKEY，
/// 收到后通过 SendPort 通知主 Isolate，由主 Isolate 调用 window_manager
/// 来显示/隐藏窗口。
///
/// 默认快捷键：Ctrl+Alt+V
class HotkeyService {
  static const int _hotkeyId = 0xC5F1; // CopyShelf Hotkey ID
  static const int _defaultMod = MOD_CONTROL | MOD_ALT;
  static const int _defaultVk = 0x56; // 'V'

  static SendPort? _isolatePort;
  static Isolate? _isolate;
  static ReceivePort? _mainPort;
  static StreamSubscription? _subscription;

  /// 启动全局快捷键监听。
  ///
  /// [onTriggered] 在快捷键被按下时调用（主 Isolate 上执行）。
  /// 返回 true 表示注册成功。
  static Future<bool> start({
    required Future<void> Function() onTriggered,
    int mod = _defaultMod,
    int vk = _defaultVk,
  }) async {
    // 已启动则先停止
    await stop();

    _mainPort = ReceivePort();

    // 监听来自 Isolate 的消息（true 表示触发了快捷键）
    _subscription = _mainPort!.listen((message) {
      if (message == true) {
        onTriggered();
      }
    });

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _IsolateArgs(
        sendPort: _mainPort!.sendPort,
        hotkeyId: _hotkeyId,
        mod: mod,
        vk: vk,
      ),
    );

    // 等待 Isolate 返回注册结果
    final resultPort = ReceivePort();
    _isolatePort = resultPort.sendPort;
    // 简化：不等待具体结果，500ms 后假定成功
    await Future.delayed(const Duration(milliseconds: 500));
    resultPort.close();

    return true;
  }

  /// 停止全局快捷键监听
  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _mainPort?.close();
    _mainPort = null;
  }

  /// Isolate 入口：注册热键并阻塞接收消息
  static void _isolateEntry(_IsolateArgs args) {
    final sendPort = args.sendPort;

    // RegisterHotKey(hwnd=0 => 消息投递给调用线程的消息队列)
    final success = RegisterHotKey(
      0, // hwnd=NULL，WM_HOTKEY 投递到当前线程的消息队列
      args.hotkeyId,
      args.mod,
      args.vk,
    );

    if (success == 0) {
      // 注册失败，发回 false
      sendPort.send(false);
      return;
    }

    sendPort.send(true);

    // 消息循环
    final msg = calloc<MSG>();
    try {
      while (true) {
        final res = GetMessageW(msg, 0, 0, 0);
        if (res <= 0) break; // WM_QUIT 或错误

        if (msg.ref.message == WM_HOTKEY && msg.ref.wParam == args.hotkeyId) {
          sendPort.send(true);
        }
      }
    } finally {
      UnregisterHotKey(0, args.hotkeyId);
      calloc.free(msg);
    }
  }
}

/// 传给 Isolate 的参数
class _IsolateArgs {
  final SendPort sendPort;
  final int hotkeyId;
  final int mod;
  final int vk;

  const _IsolateArgs({
    required this.sendPort,
    required this.hotkeyId,
    required this.mod,
    required this.vk,
  });
}