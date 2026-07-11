import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/hotkey.dart';
import 'key_caps.dart';

/// 快捷键录制器
///
/// 展示当前快捷键；点击「修改」进入录制态，直接按下新组合即完成。
/// 组合必须含 Ctrl/Alt/Win 至少一个，主键支持 A-Z、0-9、F1-F12。
class HotkeyRecorder extends StatefulWidget {
  final Hotkey value;
  final ValueChanged<Hotkey> onChanged;

  const HotkeyRecorder({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  final _focusNode = FocusNode();
  bool _isRecording = false;
  String? _hint;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _hint = null;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stopRecording();
      return KeyEventResult.handled;
    }

    // 修饰键本身按下时继续等主键
    const modifierKeys = [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    ];
    if (modifierKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    final keyboard = HardwareKeyboard.instance;
    final candidate = Hotkey(
      ctrl: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      win: keyboard.isMetaPressed,
      key: event.logicalKey.keyLabel.toUpperCase(),
    );

    if (!candidate.isValid) {
      setState(() {
        _hint = '组合需包含 Ctrl / Alt / Win 之一，主键限字母、数字或 F1-F12';
      });
      return KeyEventResult.handled;
    }

    _stopRecording();
    widget.onChanged(candidate);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTint,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accent, width: 1),
                  ),
                  child: const Text(
                    '按下新的快捷键组合…（Esc 取消）',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.accent),
                  ),
                )
              else
                KeyCaps(widget.value.parts, fontSize: 12),
              const SizedBox(width: 12),
              if (!_isRecording)
                OutlinedButton(
                  onPressed: _startRecording,
                  child: const Text('修改', style: TextStyle(fontSize: 12.5)),
                ),
            ],
          ),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _hint!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFC2410C)),
              ),
            ),
        ],
      ),
    );
  }
}
