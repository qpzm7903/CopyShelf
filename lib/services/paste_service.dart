import 'package:flutter/services.dart';

/// 粘贴服务
///
/// 通过 Method Channel 调用 Windows 原生 API：
/// 1. 将文本写入系统剪贴板
/// 2. 模拟 Ctrl+V 粘贴到前台窗口
class PasteService {
  static const _channel = MethodChannel('copyshelf/paste');

  /// 将文本粘贴到当前活动窗口
  ///
  /// 先写入系统剪贴板，再模拟 Ctrl+V。
  static Future<bool> paste(String text) async {
    try {
      await _channel.invokeMethod('paste', {'text': text});
      return true;
    } catch (e) {
      return false;
    }
  }
}
