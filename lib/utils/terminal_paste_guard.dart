/// 终端多行粘贴护栏（纯逻辑，可独立测试）
///
/// 多行片段粘进终端会被逐行自动执行，最坏可触发破坏性操作。
/// 当「内容多行 × 目标窗口是终端」时需要先弹确认框。

/// 视为终端的进程名（小写比较）。wt.exe 只是启动器，
/// Windows Terminal 常驻进程是 WindowsTerminal.exe。
const List<String> kTerminalProcessNames = [
  'cmd.exe',
  'powershell.exe',
  'pwsh.exe',
  'windowsterminal.exe',
  'conhost.exe',
  'mintty.exe',
  'alacritty.exe',
];

/// 内容是否多行（兼容 \r\n；末尾孤立换行不算多行）
bool isMultilineContent(String content) =>
    content.trimRight().contains('\n');

/// 目标进程是否终端；processName 为 null（未知/无目标）时视为非终端
bool isTerminalProcess(String? processName) {
  if (processName == null) return false;
  return kTerminalProcessNames.contains(processName.toLowerCase());
}

/// 是否需要弹终端多行粘贴确认框
bool shouldConfirmTerminalPaste({
  required String content,
  required String? targetProcessName,
  required bool suppressed,
}) {
  if (suppressed) return false;
  return isMultilineContent(content) && isTerminalProcess(targetProcessName);
}
