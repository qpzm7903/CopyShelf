import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/services/git_service.dart';

/// GitService 集成测试：用真实 git + 本地 bare 仓库模拟双设备同步。
///
/// 设备 A = GitService.init 创建的仓库；设备 B = 从 bare 远端 clone 的仓库
/// （模拟已完成首次同步的第二台设备）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String bare;
  late String dirA;
  late String dirB;
  late GitService git;

  Future<ProcessResult> run(String exe, List<String> args,
      {String? cwd}) async {
    final result = await Process.run(exe, args, workingDirectory: cwd);
    expect(result.exitCode, 0,
        reason: '$exe ${args.join(' ')} failed: ${result.stderr}');
    return result;
  }

  Future<void> writeFile(String dir, String name, String content) async {
    await File('$dir/$name').writeAsString(content);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'git_remote': 'local-bare-remote'});
    git = GitService();
    await git.ensureInitialized();

    root = await Directory.systemTemp.createTemp('copyshelf_git_test_');
    bare = '${root.path}/remote.git';
    dirA = '${root.path}/deviceA';
    dirB = '${root.path}/deviceB';

    await run('git', ['init', '--bare', bare]);

    // 设备 A：应用自建仓库 → 关联远端 → 首次推送
    await Directory(dirA).create();
    await writeFile(dirA, 'snippets.json', '[]');
    await git.init(dirA);
    await git.setRemote(dirA, bare);
    expect(await git.commitAndPush(dirA, 'initial from A'), isNull);

    // 设备 B：clone 远端（已完成首次同步的第二台设备）
    await run('git', ['clone', bare, dirB]);
    await run('git', ['config', 'user.name', 'copyshelf'], cwd: dirB);
    await run('git', ['config', 'user.email', 'copyshelf@local'], cwd: dirB);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  group('GitService 双设备同步', () {
    test('B 落后远端时 commitAndPush 仍成功（push 前自动 rebase）', () async {
      // A 推送新变更，B 不知情
      await writeFile(dirA, 'from_a.txt', 'change from A\n');
      expect(await git.commitAndPush(dirA, 'add from_a'), isNull);

      // B 直接改别的文件并推送——必须先 rebase 再 push 才能成功
      await writeFile(dirB, 'from_b.txt', 'change from B\n');
      expect(await git.commitAndPush(dirB, 'add from_b'), isNull);

      // A 拉取后两边收敛
      expect(await git.pull(dirA), isNull);
      expect(await File('$dirA/from_b.txt').exists(), isTrue);
      expect(await File('$dirB/from_a.txt').exists(), isTrue);
    });

    test('双方改同一行冲突：返回可读错误，B 本地仍可继续编辑', () async {
      await writeFile(dirA, 'snippets.json', '["edited by A"]');
      expect(await git.commitAndPush(dirA, 'A edits'), isNull);

      await writeFile(dirB, 'snippets.json', '["edited by B"]');
      final error = await git.commitAndPush(dirB, 'B edits');

      expect(error, isNotNull);
      expect(error, contains('冲突'));

      // rebase 已被 abort：仓库不在 rebase 中，本地还能正常 commit
      final status =
          await Process.run('git', ['status'], workingDirectory: dirB);
      expect((status.stdout as String).contains('rebase in progress'),
          isFalse);
      await writeFile(dirB, 'another.txt', 'still works\n');
      await run('git', ['add', '-A'], cwd: dirB);
      await run('git', ['commit', '-m', 'local edit after conflict'],
          cwd: dirB);
    });

    test('远端还是空仓库时 pull 不报错', () async {
      final emptyRemote = '${root.path}/empty.git';
      final dirC = '${root.path}/deviceC';
      await run('git', ['init', '--bare', emptyRemote]);
      await Directory(dirC).create();
      await writeFile(dirC, 'snippets.json', '[]');
      await git.init(dirC);
      await git.setRemote(dirC, emptyRemote);

      expect(await git.pull(dirC), isNull);
    });
  });
}
