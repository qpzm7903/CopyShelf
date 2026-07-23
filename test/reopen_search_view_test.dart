import 'package:copyshelf/pages/home_page.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/providers/theme_controller.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mocks.dart';

/// 呼出窗口（showSearch）必回搜索界面：既复位设置页，也把残留的编辑器路由出栈。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
          }
          return null;
        });
  });

  Future<SnippetProvider> pumpHome(WidgetTester tester) async {
    final provider = SnippetProvider(
      storage: MockStorageService(),
      git: MockGitService(),
      paste: (_) async => PasteOutcome.pasted,
    );
    await provider.loadSnippets();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(
            value: ThemeController(await StorageService.instance),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('reopen pops a left-open snippet editor back to search view',
      (tester) async {
    final provider = await pumpHome(tester);

    // 打开快速创建编辑器（模拟用户在编辑器里，然后点 X 隐藏窗口）
    await tester.tap(find.byKey(const Key('quick-create-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snippet-content-field')), findsOneWidget);
    expect(provider.isSnippetEditorOpen, isTrue);

    // 快捷键再次呼出：应把编辑器出栈，回到搜索界面
    provider.showSearch();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snippet-content-field')), findsNothing);
    expect(find.byKey(const Key('search-bar-container')), findsOneWidget);
  });

  testWidgets('reopen from settings returns to search view', (tester) async {
    final provider = await pumpHome(tester);

    provider.openSettings();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-bar-container')), findsNothing);

    provider.showSearch();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-bar-container')), findsOneWidget);
  });
}
