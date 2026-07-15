import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/constants.dart';
import 'target_window_service.dart';
import 'win32_paste.dart' as win32_paste;
import 'win32_window.dart' as win32_window;

/// 粘贴结果
enum PasteOutcome {
  /// 已写剪贴板并模拟 Ctrl+V 粘贴到目标窗口
  pasted,

  /// 仅写入剪贴板（非 Windows 平台的正常降级，静默）
  copiedOnly,

  /// 目标窗口已失效或粘贴按键未送达：内容在剪贴板里，需提示用户手动粘贴
  targetLost,

  /// 连剪贴板都没写进去
  failed,
}

/// 粘贴服务
///
/// 完整时序（见 PRD「粘贴链路」）：
/// 1. 写入系统剪贴板；
/// 2. 隐藏 CopyShelf 窗口；
/// 3. 把前台焦点还给目标窗口（呼出快捷键时由 TargetWindowService 捕获）；
/// 4. 短暂延迟等待焦点切换完成；
/// 5. SendInput 模拟 Ctrl+V。
///
/// 明确的产品行为：粘贴会占据系统剪贴板，不恢复原有内容。
class PasteService {
  /// 仅写入系统剪贴板，不隐藏窗口、不切换焦点、不模拟粘贴。
  static Future<bool> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 将文本粘贴到目标窗口。
  static Future<PasteOutcome> paste(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      return PasteOutcome.failed;
    }

    if (!Platform.isWindows) return PasteOutcome.copiedOnly;

    final hwnd = TargetWindowService.handle;
    if (hwnd == null || !win32_window.isValidWindow(hwnd)) {
      return PasteOutcome.targetLost;
    }

    try {
      await windowManager.hide();
      if (!win32_window.focusWindow(hwnd)) {
        return PasteOutcome.targetLost;
      }
      // 等待焦点切换完成后再发送按键
      await Future.delayed(AppConstants.pasteFocusDelay);
      return win32_paste.simulateCtrlV()
          ? PasteOutcome.pasted
          : PasteOutcome.targetLost;
    } catch (e) {
      return PasteOutcome.targetLost;
    }
  }
}
