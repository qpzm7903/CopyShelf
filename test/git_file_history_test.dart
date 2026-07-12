import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/services/git_service.dart';

/// 真实 git：fileHistory / snippetsAtCommit 端到端。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String dir;
  late GitService git;

  Future<void> commit(String content, String msg) async {
    await File('$dir/snippets.json').writeAsString(content);
    await Process.run('git', ['add', '-A'], workingDirectory: dir);
    await Process.run('git', ['commit', '-m', msg], workingDirectory: dir);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    git = GitService();
    await git.ensureInitialized();
    root = await Directory.systemTemp.createTemp('copyshelf_history_');
    dir = '${root.path}/repo';
    await Directory(dir).create();
    await File('$dir/snippets.json').writeAsString('[]');
    await git.init(dir);
  });

  tearDown(() async => root.delete(recursive: true));

  test('fileHistory 返回 snippets.json 的提交，最新在前', () async {
    await commit('["v1"]', 'add v1');
    await commit('["v2"]', 'change to v2');

    final history = await git.fileHistory(dir);

    expect(history.length, greaterThanOrEqualTo(3)); // init + v1 + v2
    expect(history.first.message, 'change to v2');
    expect(history.first.hash, isNotEmpty);
    expect(history.first.committedAt.year, greaterThan(2000));
  });

  test('snippetsAtCommit 取回指定提交的文件内容', () async {
    await commit('["first"]', 'first');
    final history = await git.fileHistory(dir);
    final firstAddHash =
        history.firstWhere((c) => c.message == 'first').hash;

    final content = await git.snippetsAtCommit(dir, firstAddHash);

    expect(content, contains('first'));
  });

  test('无效 hash 返回 null', () async {
    expect(await git.snippetsAtCommit(dir, 'deadbeef'), isNull);
  });
}
