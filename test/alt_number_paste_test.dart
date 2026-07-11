import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Snippet snippet(int n) => Snippet(
      id: 'id-$n', name: 'snippet-$n', content: 'content-$n');

  Future<({SnippetProvider provider, List<String> pasted})> pumpOverlay(
    WidgetTester tester, {
    int snippetCount = 12,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage
        .saveSnippets([for (var i = 1; i <= snippetCount; i++) snippet(i)]);

    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (text) async {
        pasted.add(text);
        return PasteOutcome.pasted;
      },
    );
    await provider.loadSnippets();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SearchOverlay())),
      ),
    );
    await tester.pumpAndSettle();
    return (provider: provider, pasted: pasted);
  }

  Future<void> pressAltDigit(WidgetTester tester, LogicalKeyboardKey digit) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(digit);
    await tester.sendKeyUpEvent(digit);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  group('Alt+1..9 直达粘贴', () {
    testWidgets('Alt+3 直接粘贴列表当前排序下的第 3 项', (tester) async {
      final ctx = await pumpOverlay(tester);
      final third = ctx.provider.filteredSnippets[2].content;

      await pressAltDigit(tester, LogicalKeyboardKey.digit3);

      expect(ctx.pasted, [third]);
      expect(ctx.provider.isSearchVisible, isFalse);
    });

    testWidgets('Alt+1 粘贴第 1 项，Alt+9 粘贴第 9 项', (tester) async {
      final ctx = await pumpOverlay(tester);
      final first = ctx.provider.filteredSnippets[0].content;

      await pressAltDigit(tester, LogicalKeyboardKey.digit1);
      expect(ctx.pasted, [first]);

      ctx.provider.showSearch();
      await tester.pumpAndSettle();
      final ninth = ctx.provider.filteredSnippets[8].content;
      await pressAltDigit(tester, LogicalKeyboardKey.digit9);
      expect(ctx.pasted, [first, ninth]);
    });

    testWidgets('列表不足 N 项时 Alt+N 不动作', (tester) async {
      final ctx = await pumpOverlay(tester, snippetCount: 2);

      await pressAltDigit(tester, LogicalKeyboardKey.digit5);

      expect(ctx.pasted, isEmpty);
    });

    testWidgets('不按 Alt 的数字键不触发粘贴（正常输入）', (tester) async {
      final ctx = await pumpOverlay(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();

      expect(ctx.pasted, isEmpty);
    });

    testWidgets('前 9 项渲染序号角标，第 10 项之后没有', (tester) async {
      await pumpOverlay(tester);

      expect(find.byKey(const Key('shortcut-badge-1')), findsOneWidget);
      expect(find.byKey(const Key('shortcut-badge-9')), findsOneWidget);
      expect(find.byKey(const Key('shortcut-badge-10')), findsNothing);
    });
  });
}
