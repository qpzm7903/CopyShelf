import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/models/snippet.dart';
import 'package:copyshelf/pages/search_overlay.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/importers/importer.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

/// bug-M2（HIGH）回归：含字面大括号的非模板片段必须逐字粘贴，不被当占位符。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    });
  });

  Future<({SnippetProvider provider, List<String> pasted})> pumpOverlay(
    WidgetTester tester,
    Snippet snippet,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final pasted = <String>[];
    final storage = MockStorageService();
    await storage.saveSnippets([snippet]);
    final provider = SnippetProvider(
      storage: storage,
      git: MockGitService(),
      paste: (t) async {
        pasted.add(t);
        return PasteOutcome.pasted;
      },
      targetProcessName: () => null,
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

  Future<void> pressEnter(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  testWidgets('kubectl jsonpath 含大括号：非模板逐字粘贴，不弹填表', (tester) async {
    final ctx = await pumpOverlay(
      tester,
      Snippet(
        id: 'k',
        name: 'get-pod-name',
        content: "kubectl get pods -o jsonpath='{.items[0].metadata.name}'",
      ), // isTemplate 默认 false
    );

    await pressEnter(tester);

    expect(find.byKey(const Key('placeholder-form')), findsNothing);
    expect(ctx.pasted,
        ["kubectl get pods -o jsonpath='{.items[0].metadata.name}'"]);
  });

  testWidgets('JSON 片段（非模板）逐字粘贴', (tester) async {
    final ctx = await pumpOverlay(
      tester,
      Snippet(id: 'j', name: 'json', content: '{"key": "value"}'),
    );

    await pressEnter(tester);

    expect(find.byKey(const Key('placeholder-form')), findsNothing);
    expect(ctx.pasted, ['{"key": "value"}']);
  });

  testWidgets('标记为模板的同样内容才弹填表', (tester) async {
    await pumpOverlay(
      tester,
      Snippet(
          id: 't', name: 'tpl', content: 'hello {name}', isTemplate: true),
    );

    await pressEnter(tester);

    expect(find.byKey(const Key('placeholder-form')), findsOneWidget);
  });

  test('重复导入含大括号命令不产生重复（去重按最终内容）', () {
    const candidates = [
      ImportCandidate(name: 'a', content: 'ls | % { \$_.Name }'),
    ];
    // 首次入库后库中已存该逐字内容
    final existing = {candidateToSnippetContent(candidates.first)};

    final second = dedupeCandidates(candidates, existing);

    expect(second, isEmpty);
  });
}
