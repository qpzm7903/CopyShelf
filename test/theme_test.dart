import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/providers/theme_controller.dart';
import 'package:copyshelf/services/paste_service.dart';
import 'package:copyshelf/services/storage_service.dart';
import 'package:copyshelf/theme/app_theme.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController 三态持久化', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.instance;
    });

    test('默认跟随系统', () {
      expect(ThemeController(storage).mode, ThemeMode.system);
    });

    test('设置为暗色并持久化，新实例读到暗色', () {
      final c = ThemeController(storage);
      c.setMode(ThemeMode.dark);

      expect(c.mode, ThemeMode.dark);
      // 新实例从存储读取
      expect(ThemeController(storage).mode, ThemeMode.dark);
    });

    test('三态往返', () {
      final c = ThemeController(storage);
      for (final m in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
        c.setMode(m);
        expect(c.mode, m);
      }
    });

    test('setMode 通知监听者', () {
      final c = ThemeController(storage);
      var notified = 0;
      c.addListener(() => notified++);
      c.setMode(ThemeMode.dark);
      expect(notified, 1);
    });
  });

  group('搜索窗暗色背景', () {
    testWidgets('暗色主题下搜索栏背景为暗色 surface', (tester) async {
      final storage = MockStorageService();
      await storage.saveSnippets([Snippet(id: 'a', name: 'x', content: 'y')]);
      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: SearchOverlay()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
          find.byKey(const Key('search-bar-container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.darkSurface);
    });

    testWidgets('亮色主题下搜索栏背景为亮色 surface', (tester) async {
      final storage = MockStorageService();
      await storage.saveSnippets([Snippet(id: 'a', name: 'x', content: 'y')]);
      final provider = SnippetProvider(
        storage: storage,
        git: MockGitService(),
        paste: (_) async => PasteOutcome.pasted,
      );
      await provider.loadSnippets();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            home: const Scaffold(body: SearchOverlay()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
          find.byKey(const Key('search-bar-container')));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.surface);
    });
  });
}
