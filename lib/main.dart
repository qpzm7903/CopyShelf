import 'dart:io' show Platform, exit;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/snippet_provider.dart';
import 'services/storage_service.dart';
import 'services/git_service.dart';
import 'services/hotkey_service.dart';
import 'services/single_instance_service.dart';
import 'services/target_window_service.dart';
import 'services/tray_service.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'utils/constants.dart';
import 'utils/hotkey.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 单实例锁：已有实例在运行则唤醒它并退出本进程。
  // wake 回调此刻还拿不到窗口逻辑，先经由间接层，初始化完成后再赋值。
  Future<void> Function()? wakeHandler;
  final singleInstance = SingleInstanceService();
  final lockAcquired = await singleInstance.tryAcquire(
    onWake: () async => wakeHandler?.call(),
  );
  if (!lockAcquired) {
    await SingleInstanceService.notifyExisting();
    exit(0);
  }

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(600, 500),
    minimumSize: const Size(500, 300),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: AppConstants.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 点 X 不结束进程：交给 HomePage.onWindowClose 隐藏到托盘
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  // 初始化服务
  final storage = await StorageService.instance;
  final git = await GitService.instance;

  // 创建片段状态管理器
  final snippetProvider = SnippetProvider(
    storage: storage,
    git: git,
  );

  // 完整初始化（数据目录、Git、加载片段）
  await snippetProvider.init();

  // 呼出/隐藏搜索窗口（快捷键与托盘左键共用）
  Future<void> toggleSearchWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      // 必须在 show 之前捕获：show 之后前台窗口就是 CopyShelf 自己了
      TargetWindowService.capture();
      await windowManager.show();
      await windowManager.focus();
      snippetProvider.showSearch();
    }
  }

  // 次实例唤醒：无论当前是否可见都呼出并聚焦搜索窗（与 toggle 不同，不隐藏）
  wakeHandler = () async {
    if (!await windowManager.isVisible()) {
      TargetWindowService.capture();
    }
    await windowManager.show();
    await windowManager.focus();
    snippetProvider.showSearch();
  };

  if (Platform.isWindows) {
    // 注册全局快捷键（默认 Ctrl+Alt+V，可在设置中修改）
    final hotkey = Hotkey.parse(storage.hotkey) ?? Hotkey.defaultHotkey;
    final registration = await HotkeyService.start(
      onTriggered: toggleSearchWindow,
      mod: hotkey.modifiers,
      vk: hotkey.virtualKey!,
    );
    if (!registration.ok) {
      snippetProvider.setHotkeyError(
        '全局快捷键 ${hotkey.format()} 注册失败：${registration.reason}。'
        '请在下方更换快捷键。',
      );
    }

    // 系统托盘：左键切换窗口，右键菜单打开设置/退出
    late final TrayService tray;
    tray = TrayService(
      onToggleWindow: toggleSearchWindow,
      onOpenSettings: () async {
        snippetProvider.openSettings();
        await windowManager.show();
        await windowManager.focus();
      },
      onExit: () async {
        // 退出前清理快捷键注册、单实例锁与托盘图标
        await HotkeyService.stop();
        await singleInstance.dispose();
        await tray.dispose();
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        exit(0);
      },
    );
    await tray.init();
  }

  runApp(CopyShelfApp(snippetProvider: snippetProvider));
}

class CopyShelfApp extends StatelessWidget {
  final SnippetProvider snippetProvider;

  const CopyShelfApp({super.key, required this.snippetProvider});

  @override
  Widget build(BuildContext context) {
    final defaultFontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;

    return ChangeNotifierProvider.value(
      value: snippetProvider,
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