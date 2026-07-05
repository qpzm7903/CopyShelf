import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';

import 'providers/command_provider.dart';
import 'services/storage_service.dart';
import 'services/git_service.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'utils/constants.dart';

/// 系统托盘实例
final SystemTray systemTray = SystemTray();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(600, 500),
    minimumSize: Size(500, 300),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: AppConstants.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化服务
  final storage = await StorageService.instance;
  final git = await GitService.instance;

  // 创建指令状态管理器
  final commandProvider = CommandProvider(
    storage: storage,
    git: git,
  );

  // 完整初始化（数据目录、Git、加载指令）
  await commandProvider.init();

  // 设置系统托盘
  await _initSystemTray();

  // 注册全局快捷键
  await _initHotkey(commandProvider);

  runApp(CopyShelfApp(commandProvider: commandProvider));
}

Future<void> _initSystemTray() async {
  if (!Platform.isWindows) return;

  try {
    await systemTray.initSystemTray(
      iconData: 'assets/icon.png',
      toolTip: AppConstants.appName,
    );

    await systemTray.setContextMenu(
      [
        MenuItemLabel(
          label: '显示',
          onClicked: (_) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuItemLabel(
          label: '设置',
          onClicked: (_) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        const MenuSeparator(),
        MenuItemLabel(
          label: '退出',
          onClicked: (_) async {
            await windowManager.destroy();
          },
        ),
      ],
    );

    systemTray.onLeftClick = (_) async {
      await windowManager.show();
      await windowManager.focus();
    };
  } catch (e) {
    // 系统托盘初始化失败不阻塞启动
  }
}

Future<void> _initHotkey(CommandProvider commandProvider) async {
  if (!Platform.isWindows) return;

  try {
    await hotKeyManager.register(
      HotKey(
        KeyCode.keyV,
        modifiers: [KeyModifier.control, KeyModifier.alt],
      ),
      keyDownHandler: (hotKey) async {
        if (await windowManager.isVisible()) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
          commandProvider.showSearch();
        }
      },
    );
  } catch (e) {
    // 快捷键注册失败不阻塞
  }
}

class CopyShelfApp extends StatelessWidget {
  final CommandProvider commandProvider;

  const CopyShelfApp({super.key, required this.commandProvider});

  @override
  Widget build(BuildContext context) {
    final defaultFontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;

    return ChangeNotifierProvider.value(
      value: commandProvider,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(fontFamily: defaultFontFamily),
        darkTheme: AppTheme.dark(fontFamily: defaultFontFamily),
        themeMode: ThemeMode.light,
        home: const HomePage(),
      ),
    );
  }
}
