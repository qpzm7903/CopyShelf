import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'hotkey_messages.dart';

/// 全局快捷键服务
///
/// 在独立 Isolate 中调用 RegisterHotKey + GetMessageW 阻塞接收 WM_HOTKEY，
/// 收到后通过 SendPort 通知主 Isolate，由主 Isolate 调用 window_manager
/// 来显示/隐藏窗口。
///
/// 消息协议见 [HotkeyMessages]：注册结果与热键触发是两种可区分的消息，
/// 注册失败（如快捷键被其他程序占用）会以 [HotkeyRegistration.failure] 返回。
///
/// 默认快捷键：Ctrl+Alt+V
class HotkeyService {
  static const int _hotkeyId = 0xC5F1; // CopyShelf Hotkey ID
  static const int _defaultMod = MOD_CONTROL | MOD_ALT;
  static const int _defaultVk = 0x56; // 'V'

  static Isolate? _isolate;
  static ReceivePort? _mainPort;
  static StreamSubscription? _subscription;
  static Future<void> Function()? _onTriggered;

  /// 启动全局快捷键监听。
  ///
  /// [onTriggered] 在快捷键被按下时调用（主 Isolate 上执行）。
  /// 返回注册结果；失败时携带可读原因（被占用/系统错误码/超时）。
  static Future<HotkeyRegistration> start({
    required Future<void> Function() onTriggered,
    int mod = _defaultMod,
    int vk = _defaultVk,
  }) async {
    // 已启动则先停止
    await stop();
    _onTriggered = onTriggered;

    final dispatcher = HotkeyMessageDispatcher(onTriggered: () {
      onTriggered();
    });

    _mainPort = ReceivePort();
    _subscription = _mainPort!.listen(dispatcher.handleMessage);

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _IsolateArgs(
        sendPort: _mainPort!.sendPort,
        hotkeyId: _hotkeyId,
        mod: mod,
        vk: vk,
      ),
    );

    final result = await dispatcher.registration;
    if (!result.ok) {
      // 注册失败的 Isolate 已自行退出，清理监听资源
      await stop();
    }
    return result;
  }

  /// 用新的按键组合重新注册（设置页修改快捷键后调用）。
  ///
  /// 沿用 start 时传入的回调；从未 start 过则返回失败。
  static Future<HotkeyRegistration> updateHotkey({
    required int mod,
    required int vk,
  }) async {
    final onTriggered = _onTriggered;
    if (onTriggered == null) {
      return const HotkeyRegistration.failure('快捷键服务尚未启动');
    }
    return start(onTriggered: onTriggered, mod: mod, vk: vk);
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
      sendPort.send(HotkeyMessages.registeredMessage(
        ok: false,
        errorCode: GetLastError(),
      ));
      return;
    }

    sendPort.send(HotkeyMessages.registeredMessage(ok: true));

    // 消息循环
    final msg = calloc<MSG>();
    try {
      while (true) {
        final res = GetMessage(msg, 0, 0, 0);
        if (res <= 0) break; // WM_QUIT 或错误

        if (msg.ref.message == WM_HOTKEY && msg.ref.wParam == args.hotkeyId) {
          sendPort.send(HotkeyMessages.triggeredMessage());
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
