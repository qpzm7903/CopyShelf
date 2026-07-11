import 'package:win32/win32.dart';

/// Win32 窗口操作的薄封装（仅 Windows 平台调用）。
///
/// 用于目标窗口（Target Window）的捕获与焦点归还：
/// 呼出快捷键那一刻的前台窗口是片段最终要粘贴到的地方。

/// 当前前台窗口句柄，无前台窗口时返回 null。
int? foregroundWindow() {
  final hwnd = GetForegroundWindow();
  return hwnd == 0 ? null : hwnd;
}

/// 句柄是否仍指向一个存在的窗口。
bool isValidWindow(int hwnd) => IsWindow(hwnd) != 0;

/// 把焦点还给目标窗口。返回 false 表示系统拒绝切换前台。
bool focusWindow(int hwnd) => SetForegroundWindow(hwnd) != 0;
