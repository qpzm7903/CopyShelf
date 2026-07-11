import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/pages/settings_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SnippetProvider> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = SnippetProvider(
      storage: MockStorageService(),
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('设置页热键状态横幅', () {
    testWidgets('热键注册失败时显示错误横幅', (tester) async {
      // Arrange
      final provider = await pumpSettings(tester);

      // Act
      provider.setHotkeyError('快捷键 Ctrl+Alt+V 注册失败：已被其他程序占用，请更换快捷键');
      await tester.pump();

      // Assert
      expect(find.byKey(const Key('hotkey-error-banner')), findsOneWidget);
      expect(find.textContaining('已被其他程序占用'), findsOneWidget);
    });

    testWidgets('无错误时不渲染横幅', (tester) async {
      await pumpSettings(tester);

      expect(find.byKey(const Key('hotkey-error-banner')), findsNothing);
    });

    testWidgets('错误被清除后横幅消失', (tester) async {
      final provider = await pumpSettings(tester);
      provider.setHotkeyError('注册失败');
      await tester.pump();

      provider.setHotkeyError(null);
      await tester.pump();

      expect(find.byKey(const Key('hotkey-error-banner')), findsNothing);
    });
  });
}
