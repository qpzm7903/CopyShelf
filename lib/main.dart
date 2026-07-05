import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/command_provider.dart';
import 'services/storage_service.dart';
import 'services/git_service.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
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

  // 设置系统托盘和全局快捷键（Windows only，失败不阻塞）
  if (Platform.isWindows) {
    await _initSystemTray(commandProvider);
    await _initHotkey(commandProvider);
  }

  runApp(CopyShelfApp(commandProvider: commandProvider));
}

Future<void> _initSystemTray(CommandProvider commandProvider) async {
  // system_tray 2.x API:
  // initSystemTray(icon: String path, toolTip: String)
  // setContextMenu(Menu menu)
  // 注意：需要 assets/icon.ico 或 .png 文件
  // 暂时跳过托盘初始化，依赖全局快捷键和窗口管理
}

Future<void> _initHotkey(CommandProvider commandProvider) async {
  // hotkey_manager API 在不同版本间不兼容
  // 暂时跳过全局快捷键注册，依赖窗口管理
  // TODO: 后续版本实现
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
