import 'dart:async';

/// 热键 Isolate 与主 Isolate 之间的消息协议与分发（纯 Dart，可独立测试）。
///
/// 旧协议用裸 bool 同时表示「注册结果」和「热键触发」，两者无法区分，
/// 注册成功的握手消息会被当成一次热键触发。新协议改用带 type 字段的 Map。

/// win32 ERROR_HOTKEY_ALREADY_REGISTERED
const int _errorHotkeyAlreadyRegistered = 1409;

/// 等待 Isolate 返回注册结果的默认超时
const Duration _defaultRegistrationTimeout = Duration(seconds: 3);

/// 热键注册结果
class HotkeyRegistration {
  final bool ok;
  final String? reason;

  const HotkeyRegistration.success()
      : ok = true,
        reason = null;

  const HotkeyRegistration.failure(String this.reason) : ok = false;
}

/// 消息构造与字段常量（Isolate 两侧共用，保证协议一致）
class HotkeyMessages {
  static const String typeKey = 'type';
  static const String typeRegistered = 'registered';
  static const String typeTriggered = 'triggered';
  static const String okKey = 'ok';
  static const String errorCodeKey = 'errorCode';

  /// 注册结果消息；失败时可携带 win32 GetLastError 错误码
  static Map<String, Object> registeredMessage({
    required bool ok,
    int? errorCode,
  }) =>
      {
        typeKey: typeRegistered,
        okKey: ok,
        if (errorCode != null) errorCodeKey: errorCode,
      };

  /// 热键被按下消息
  static Map<String, Object> triggeredMessage() => {typeKey: typeTriggered};
}

/// 主 Isolate 侧的消息分发器：
/// 把 Isolate 发来的消息解码为「注册结果」或「热键触发」。
class HotkeyMessageDispatcher {
  final void Function() onTriggered;
  final Duration registrationTimeout;
  final Completer<HotkeyRegistration> _registered =
      Completer<HotkeyRegistration>();

  HotkeyMessageDispatcher({
    required this.onTriggered,
    this.registrationTimeout = _defaultRegistrationTimeout,
  });

  /// 注册结果；超时未收到消息视为失败
  Future<HotkeyRegistration> get registration =>
      _registered.future.timeout(
        registrationTimeout,
        onTimeout: () =>
            const HotkeyRegistration.failure('等待热键注册结果超时'),
      );

  /// 处理来自 Isolate 的一条消息；无法识别的消息一律忽略
  void handleMessage(Object? message) {
    if (message is! Map) return;
    switch (message[HotkeyMessages.typeKey]) {
      case HotkeyMessages.typeRegistered:
        _completeRegistration(message);
      case HotkeyMessages.typeTriggered:
        onTriggered();
    }
  }

  void _completeRegistration(Map<Object?, Object?> message) {
    if (_registered.isCompleted) return;
    if (message[HotkeyMessages.okKey] == true) {
      _registered.complete(const HotkeyRegistration.success());
      return;
    }
    final errorCode = message[HotkeyMessages.errorCodeKey];
    final reason = errorCode == _errorHotkeyAlreadyRegistered
        ? '该快捷键已被其他程序占用'
        : '注册失败（系统错误码 $errorCode）';
    _registered.complete(HotkeyRegistration.failure(reason));
  }
}
