import 'dart:ffi';

import 'package:ffi/ffi.dart';
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

/// 窗口所属进程 PID；失败返回 null。
int? windowProcessId(int hwnd) {
  final pidPtr = calloc<Uint32>();
  try {
    GetWindowThreadProcessId(hwnd, pidPtr);
    final pid = pidPtr.value;
    return pid == 0 ? null : pid;
  } finally {
    calloc.free(pidPtr);
  }
}

/// PID 对应的可执行文件名（如 `cmd.exe`，保留原大小写）；失败返回 null。
String? processNameForPid(int pid) {
  final hProcess =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (hProcess == 0) return null;

  final buffer = wsalloc(MAX_PATH);
  final size = calloc<Uint32>()..value = MAX_PATH;
  try {
    final ok = QueryFullProcessImageName(hProcess, 0, buffer, size);
    if (ok == 0) return null;
    final fullPath = buffer.toDartString();
    final lastSep = fullPath.lastIndexOf('\\');
    return lastSep == -1 ? fullPath : fullPath.substring(lastSep + 1);
  } finally {
    free(buffer);
    calloc.free(size);
    CloseHandle(hProcess);
  }
}
