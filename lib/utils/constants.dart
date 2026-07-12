/// 应用常量

class AppConstants {
  static const String appName = 'CopyShelf';
  static const String version = '0.1.14';

  // 默认数据目录（相对用户目录）
  static const String defaultDataDirName = '.copyshelf';

  // 数据文件名
  static const String snippetsFileName = 'snippets.json';
  // 使用统计文件名（本地文件，不参与 Git 同步，见 ADR-0001）
  static const String statsFileName = 'stats.json';

  // 粘贴：归还焦点后等待目标窗口就绪的延迟
  static const Duration pasteFocusDelay = Duration(milliseconds: 50);

  // 快捷键
  static const String defaultHotkey = 'Ctrl+Alt+V';
  static const String prefKeyHotkey = 'hotkey';
  static const String prefKeyDataDir = 'data_dir';
  static const String prefKeyGitRemote = 'git_remote';
  // 终端多行粘贴确认框的「不再提醒」
  static const String prefKeySuppressTerminalPasteWarning =
      'suppress_terminal_paste_warning';
}
