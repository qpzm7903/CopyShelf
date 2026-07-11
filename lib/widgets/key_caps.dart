import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 键帽（kbd）展示：`[Ctrl] [Alt] [V]`
///
/// 快捷键在全应用的统一视觉语言：搜索框、底部提示栏、设置页均用它。
class KeyCaps extends StatelessWidget {
  final List<String> keys;
  final double fontSize;

  const KeyCaps(this.keys, {super.key, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          _KeyCap(label: keys[i], fontSize: fontSize),
        ],
      ],
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String label;
  final double fontSize;

  const _KeyCap({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.hairline),
        boxShadow: const [
          BoxShadow(color: AppTheme.hairline, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamilyFallback: AppTheme.monoFontFallback,
          fontSize: fontSize,
          height: 1.2,
          color: AppTheme.inkSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
