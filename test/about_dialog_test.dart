import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/pages/settings_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/providers/theme_controller.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/utils/constants.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final provider = SnippetProvider(
      storage: MockStorageService(),
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    final theme = ThemeController(await StorageService.instance);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('关于对话框', () {
    testWidgets('点关于按钮弹出对话框，显示版本号与开源地址', (tester) async {
      await pumpSettings(tester);

      await tester.ensureVisible(find.byKey(const Key('about-button')));
      await tester.tap(find.byKey(const Key('about-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('about-dialog')), findsOneWidget);
      expect(find.textContaining('v${AppConstants.version}'), findsWidgets);
      expect(find.textContaining('github.com/qpzm7903/CopyShelf'),
          findsOneWidget);
    });

    testWidgets('对话框内有检查更新按钮', (tester) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.byKey(const Key('about-button')));
      await tester.tap(find.byKey(const Key('about-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('check-update-button')), findsOneWidget);
    });
  });
}
