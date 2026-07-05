import 'package:flutter/material.dart';

/// CopyShelf 主题
///
/// 沿用参考项目的国内审美风格：去阴影、灰底白卡、0.5px 极细线、去水波纹。
class AppTheme {
  static const _primaryColor = Color(0xFF6366F1); // 靛蓝色调

  static ThemeData light({String? fontFamily}) {
    final base = ThemeData(
      useMaterial3: false,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF333333),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0xFFEEEEEE),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        titleTextStyle: TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: Color(0xFF999999),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
        bodyLarge: TextStyle(fontSize: 14, color: Color(0xFF333333)),
        bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF666666)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF999999)),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

    return base;
  }

  static ThemeData dark({String? fontFamily}) {
    final base = ThemeData(
      useMaterial3: false,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF222222),
        foregroundColor: Color(0xFFE0E0E0),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF2A2A2A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: Color(0xFF333333),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF333333),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF444444), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF444444), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        titleTextStyle: TextStyle(
          fontSize: 14,
          color: Color(0xFFE0E0E0),
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: Color(0xFF999999),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE0E0E0)),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE0E0E0)),
        bodyLarge: TextStyle(fontSize: 14, color: Color(0xFFE0E0E0)),
        bodyMedium: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF888888)),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

    return base;
  }
}
