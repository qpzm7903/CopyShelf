/// 全局快捷键的解析/格式化模型
///
/// 与 win32 解耦（常量值等同 MOD_*/VK_*），纯 Dart 可单测。
/// 存储格式如 `Ctrl+Alt+V`，主键支持 A-Z、0-9、F1-F12。
class Hotkey {
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool win;

  /// 主键，规范化为大写：'V'、'7'、'F2'
  final String key;

  const Hotkey({
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.win = false,
    required this.key,
  });

  static const Hotkey defaultHotkey = Hotkey(ctrl: true, alt: true, key: 'V');

  // 等同 win32 的 MOD_ALT / MOD_CONTROL / MOD_SHIFT / MOD_WIN
  static const int modAlt = 0x0001;
  static const int modControl = 0x0002;
  static const int modShift = 0x0004;
  static const int modWin = 0x0008;

  static final RegExp _keyPattern = RegExp(r'^([A-Z]|[0-9]|F([1-9]|1[0-2]))$');

  /// RegisterHotKey 的修饰键位掩码
  int get modifiers =>
      (alt ? modAlt : 0) |
      (ctrl ? modControl : 0) |
      (shift ? modShift : 0) |
      (win ? modWin : 0);

  /// 主键的 Virtual-Key Code；不支持的主键返回 null
  int? get virtualKey {
    if (!_keyPattern.hasMatch(key)) return null;
    if (key.startsWith('F') && key.length > 1) {
      final n = int.parse(key.substring(1));
      return 0x70 + n - 1; // VK_F1 = 0x70
    }
    return key.codeUnitAt(0); // A-Z: 0x41-0x5A, 0-9: 0x30-0x39
  }

  /// 可注册的快捷键：主键合法，且至少含 Ctrl/Alt/Win 之一
  /// （仅 Shift+字母会和正常输入冲突）
  bool get isValid => virtualKey != null && (ctrl || alt || win);

  /// 键帽显示顺序：Ctrl, Alt, Shift, Win, 主键
  List<String> get parts => [
        if (ctrl) 'Ctrl',
        if (alt) 'Alt',
        if (shift) 'Shift',
        if (win) 'Win',
        key,
      ];

  String format() => parts.join('+');

  /// 解析 `Ctrl+Alt+V` 形式的字符串；非法输入返回 null
  static Hotkey? parse(String input) {
    final tokens = input
        .split('+')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    var ctrl = false, alt = false, shift = false, win = false;
    String? key;
    for (final token in tokens) {
      switch (token.toLowerCase()) {
        case 'ctrl':
        case 'control':
          ctrl = true;
          break;
        case 'alt':
          alt = true;
          break;
        case 'shift':
          shift = true;
          break;
        case 'win':
        case 'meta':
          win = true;
          break;
        default:
          if (key != null) return null; // 出现两个主键
          key = token.toUpperCase();
      }
    }
    if (key == null || !_keyPattern.hasMatch(key)) return null;

    final hotkey =
        Hotkey(ctrl: ctrl, alt: alt, shift: shift, win: win, key: key);
    return hotkey.isValid ? hotkey : null;
  }
}
