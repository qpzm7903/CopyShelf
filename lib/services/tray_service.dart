import 'package:tray_manager/tray_manager.dart';

/// 系统托盘服务
///
/// 常驻托盘图标：左键单击切换搜索窗口，右键菜单提供「打开设置」「退出」。
/// 退出是结束进程的唯一入口（主窗口点 X 只是隐藏到托盘）。
class TrayService with TrayListener {
  TrayService({
    required this.onOpenSettings,
    required this.onToggleWindow,
    required this.onExit,
  });

  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onToggleWindow;
  final Future<void> Function() onExit;

  static const String _menuKeySettings = 'open_settings';
  static const String _menuKeyExit = 'exit';

  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon('assets/app_icon.ico');
    await trayManager.setToolTip('CopyShelf');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: _menuKeySettings, label: '打开设置'),
      MenuItem.separator(),
      MenuItem(key: _menuKeyExit, label: '退出'),
    ]));
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    onToggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuKeySettings:
        onOpenSettings();
        break;
      case _menuKeyExit:
        onExit();
        break;
    }
  }
}
