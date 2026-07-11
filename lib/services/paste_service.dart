import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'win32_paste.dart' as win32_paste;

/// 粘贴服务
///
/// 将片段内容写入系统剪贴板，并在 Windows 平台上模拟 Ctrl+V 按键，
/// 把内容自动粘贴到前台窗口。
///
/// Windows 实现使用 win32 包（纯 Dart 绑定）调用 User32 API：
/// - 写入剪贴板通过 Flutter 内置 Clipboard API
/// - 模拟 Ctrl+V 通过 win32 的 SendInput
class PasteService {
  /// 将文本粘贴到当前活动窗口
  ///
  /// 返回 true 表示已写入剪贴板 + 模拟 Ctrl+V；
  /// 返回 false 表示仅写入剪贴板（非 Windows 或模拟按键失败）。
  static Future<bool> paste(String text) async {
    bool copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      copied = true;
    } catch (e) {
      copied = false;
    }

    if (!copied) return false;

    if (!Platform.isWindows) return true;

    try {
      return win32_paste.simulateCtrlV();
    } catch (e) {
      return false;
    }
  }
}