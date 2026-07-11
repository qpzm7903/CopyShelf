import 'dart:io' show Platform;
import 'win32_window.dart' as win32_window;

/// 目标窗口追踪
///
/// 「目标窗口」= 按下呼出快捷键那一瞬间的前台窗口（见 CONTEXT.md）。
/// 必须在显示 CopyShelf 窗口**之前**捕获，否则前台已经变成 CopyShelf 自己。
class TargetWindowService {
  static int? _handle;

  /// 在呼出搜索窗口前调用，记录当前前台窗口。
  static void capture() {
    if (!Platform.isWindows) return;
    _handle = win32_window.foregroundWindow();
  }

  /// 呼出时捕获的目标窗口句柄；未捕获过为 null。
  static int? get handle => _handle;

  static void clear() {
    _handle = null;
  }
}
