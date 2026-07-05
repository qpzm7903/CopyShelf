import 'package:flutter/services.dart';

/// 粘贴服务
///
/// 使用 Flutter 内置的 Clipboard API 将文本写入系统剪贴板。
/// 用户选中指令后，内容已到剪贴板，按 Ctrl+V 即可粘贴。
///
/// TODO: v0.2 实现自动模拟 Ctrl+V（需要 Win32 平台通道或 dart:ffi）
class PasteService {
  /// 将文本复制到系统剪贴板
  static Future<bool> paste(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e) {
      return false;
    }
  }
}
