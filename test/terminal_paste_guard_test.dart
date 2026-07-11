import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/utils/terminal_paste_guard.dart';
import 'package:copyshelf/services/win32_window.dart' as win32_window;

void main() {
  group('终端多行粘贴判定（纯函数）', () {
    test('多行内容 × 终端进程 = 需要确认', () {
      expect(
        shouldConfirmTerminalPaste(
          content: 'line1\nline2',
          targetProcessName: 'cmd.exe',
          suppressed: false,
        ),
        isTrue,
      );
    });

    test('终端进程名大小写不敏感（WindowsTerminal.exe / pwsh.exe）', () {
      for (final name in ['WindowsTerminal.exe', 'PWSH.EXE', 'PowerShell.exe']) {
        expect(isTerminalProcess(name), isTrue, reason: name);
      }
    });

    test('单行内容直通（即使目标是终端）', () {
      expect(
        shouldConfirmTerminalPaste(
          content: 'git status',
          targetProcessName: 'cmd.exe',
          suppressed: false,
        ),
        isFalse,
      );
    });

    test('末尾孤立换行不算多行', () {
      expect(isMultilineContent('git status\n'), isFalse);
      expect(isMultilineContent('a\r\nb'), isTrue);
    });

    test('非终端进程直通（即使内容多行）', () {
      expect(
        shouldConfirmTerminalPaste(
          content: 'line1\nline2',
          targetProcessName: 'Code.exe',
          suppressed: false,
        ),
        isFalse,
      );
    });

    test('目标进程未知（null）直通', () {
      expect(isTerminalProcess(null), isFalse);
    });

    test('「不再提醒」后直通', () {
      expect(
        shouldConfirmTerminalPaste(
          content: 'line1\nline2',
          targetProcessName: 'cmd.exe',
          suppressed: true,
        ),
        isFalse,
      );
    });
  });

  group('进程名解析（真实 win32，仅 Windows CI）', () {
    test('解析自身进程名返回 .exe 文件名', () {
      final name = win32_window.processNameForPid(pid);

      expect(name, isNotNull);
      expect(name!.toLowerCase(), endsWith('.exe'));
      expect(name.contains('\\'), isFalse);
    }, skip: !Platform.isWindows ? 'win32 进程解析仅在 Windows 上可测' : false);
  });
}
