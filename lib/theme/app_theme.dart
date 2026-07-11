import 'package:flutter/material.dart';

/// CopyShelf 主题
///
/// 设计基调：暖灰底、白卡、发丝线、无阴影无水波纹；强调色只出现在
/// 「当前选中/主操作」一处。签名元素：片段内容一律等宽字体
/// （命令/代码/prompt 工具的身份），见 [monoFontFallback]。
class AppTheme {
  // ---- 设计 token（自绘组件直接引用） ----
  static const Color accent = Color(0xFF4F46E5); // indigo-600
  static const Color accentTint = Color(0xFFEEF0FE); // 选中底色
  static const Color ink = Color(0xFF23262B); // 主文字
  static const Color inkSecondary = Color(0xFF878E98); // 次级文字
  static const Color inkFaint = Color(0xFFB9BEC6); // 辅助/占位
  static const Color canvas = Color(0xFFF6F6F4); // 页面底
  static const Color surface = Colors.white; // 卡面
  static const Color hairline = Color(0xFFE9E9E6); // 细线

  /// 片段内容的等宽字体链（Windows 优先 Cascadia，兜底 Consolas）
  static const List<String> monoFontFallback = [
    'Cascadia Mono',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  /// 内容预览/编辑用的等宽样式
  static TextStyle mono({
    double fontSize = 12.5,
    Color color = inkSecondary,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamilyFallback: monoFontFallback,
      fontSize: fontSize,
      color: color,
      height: height,
    );
  }

  static ThemeData light({String? fontFamily}) {
    return ThemeData(
      useMaterial3: false,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: hairline, width: 0.5)),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: hairline, width: 0.5),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: hairline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F3F1),
        hintStyle: const TextStyle(color: inkFaint, fontSize: 13),
        labelStyle: const TextStyle(color: inkSecondary, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: accent, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: hairline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      textTheme: const TextTheme(
        titleLarge:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        titleMedium:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
        bodyLarge: TextStyle(fontSize: 14, color: ink),
        bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF5A6068)),
        bodySmall: TextStyle(fontSize: 12, color: inkSecondary),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: const Color(0xFFF2F2EF),
    );
  }

  /// 暗色主题暂未启用（themeMode 固定 light），保留接口
  static ThemeData dark({String? fontFamily}) => light(fontFamily: fontFamily);
}
