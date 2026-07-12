import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 主题模式控制器：三态（跟随系统 / 亮 / 暗），持久化到 shared_preferences。
class ThemeController extends ChangeNotifier {
  final StorageService _storage;

  ThemeController(this._storage);

  ThemeMode get mode => _parse(_storage.themeMode);

  /// 设置并持久化主题模式
  void setMode(ThemeMode value) {
    _storage.themeMode = _serialize(value);
    notifyListeners();
  }

  static ThemeMode _parse(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// StorageService 的主题模式读写扩展（键集中在 constants）
extension ThemeModeStorage on StorageService {
  String get themeMode => rawString(AppConstants.prefKeyThemeMode) ?? 'system';
  set themeMode(String value) =>
      setRawString(AppConstants.prefKeyThemeMode, value);
}
