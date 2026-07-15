import 'package:copyshelf/pages/settings_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/providers/theme_controller.dart';
import 'package:copyshelf/services/hotkey_messages.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SnippetProvider> pumpSettings(
    WidgetTester tester,
    Future<HotkeyRegistration> Function({required int mod, required int vk})
    updater,
  ) async {
    SharedPreferences.setMockInitialValues({'hotkey': 'Ctrl+Alt+V'});
    final storage = await StorageService.instance;
    storage.hotkey = 'Ctrl+Alt+V';
    final provider = SnippetProvider(
      storage: MockStorageService(),
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: ThemeController(storage)),
        ],
        child: MaterialApp(
          home: SettingsPage(isWindowsOverride: true, hotkeyUpdater: updater),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> recordCtrlShiftP(WidgetTester tester) async {
    await tester.tap(find.text('修改'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('failed new hotkey restores old registration and storage', (
    tester,
  ) async {
    final calls = <({int mod, int vk})>[];
    var attempt = 0;
    final provider = await pumpSettings(tester, ({
      required mod,
      required vk,
    }) async {
      calls.add((mod: mod, vk: vk));
      attempt++;
      return attempt == 1
          ? const HotkeyRegistration.failure('已被占用')
          : const HotkeyRegistration.success();
    });

    await recordCtrlShiftP(tester);

    final storage = await StorageService.instance;
    expect(calls, hasLength(2));
    expect(calls[0], (mod: 0x0002 | 0x0004, vk: 0x50));
    expect(calls[1], (mod: 0x0002 | 0x0001, vk: 0x56));
    expect(storage.hotkey, 'Ctrl+Alt+V');
    expect(provider.hotkeyError, contains('已恢复'));
  });

  testWidgets('successful new hotkey is persisted after registration', (
    tester,
  ) async {
    final calls = <({int mod, int vk})>[];
    final provider = await pumpSettings(tester, ({
      required mod,
      required vk,
    }) async {
      calls.add((mod: mod, vk: vk));
      return const HotkeyRegistration.success();
    });

    await recordCtrlShiftP(tester);

    final storage = await StorageService.instance;
    expect(calls, hasLength(1));
    expect(storage.hotkey, 'Ctrl+Shift+P');
    expect(provider.hotkeyError, isNull);
  });

  testWidgets('registration exception also restores the old hotkey', (
    tester,
  ) async {
    var attempt = 0;
    final provider = await pumpSettings(tester, ({
      required mod,
      required vk,
    }) async {
      attempt++;
      if (attempt == 1) throw StateError('channel closed');
      return const HotkeyRegistration.success();
    });

    await recordCtrlShiftP(tester);

    final storage = await StorageService.instance;
    expect(attempt, 2);
    expect(storage.hotkey, 'Ctrl+Alt+V');
    expect(provider.hotkeyError, contains('系统异常'));
    expect(provider.hotkeyError, contains('已恢复'));
  });
}
