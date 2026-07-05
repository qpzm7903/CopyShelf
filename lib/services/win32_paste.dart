import 'package:win32/win32.dart';

/// 在 Windows 平台模拟一次 Ctrl+V 按键，把已写入剪贴板的内容粘贴到前台窗口。
///
/// 基于纯 Dart 的 win32 包调用 User32 API，无需 C++ 平台通道。
///
/// 返回 true 表示 SendInput 成功发送了 4 个事件（Ctrl/V 按下+释放）；
/// 返回 false 表示调用失败。
bool simulateCtrlV() {
  final inputs = List<INPUT>.filled(4, INPUT());

  // 1. Ctrl 按下
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;
  inputs[0].ki.dwFlags = 0;

  // 2. V 按下
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'V'.codeUnitAt(0);
  inputs[1].ki.dwFlags = 0;

  // 3. V 释放
  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'V'.codeUnitAt(0);
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

  // 4. Ctrl 释放
  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  final sent = SendInput(inputs.length, inputs.elementAt(0), INPUT_SIZE);
  return sent == inputs.length;
}