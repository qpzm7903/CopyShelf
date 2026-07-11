import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/services/git_service.dart';

/// 首次同步引导（issue 07）：第二台设备配置远端时的自动引导。
///
/// 场景：全新设备先 git init 出 scaffold（`[]` 的 snippets.json + init commit），
/// 用户再配置远端。此时本地历史与远端不相关，且双方都「添加」了 snippets.json，
/// 直接 pull --rebase 必然 add/add 冲突。configureRemote 需要识别 scaffold
/// 状态并自动以远端为准。
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

    root = await Directory.systemTemp.createTemp('copyshelf_firstsync_');
    bare = '${root.path}/remote.git';
    dirA = '${root.path}/deviceA';
    dirB = '${root.path}/deviceB';

    await run('git', ['init', '--bare', bare]);

    // 设备 A：已有片段并推送到远端
    await Directory(dirA).create();
    await writeFile(dirA, 'snippets.json',
        '[{"id":"a1","name":"from-A","content":"echo hello"}]');
    await git.init(dirA);
    await git.setRemote(dirA, bare);
    expect(await git.commitAndPush(dirA, 'snippets from A'), isNull);

    // 设备 B：全新设备零配置启动（scaffold：空片段 + init commit），未配远端
    await Directory(dirB).create();
    await writeFile(dirB, 'snippets.json', '[]');
    await git.init(dirB);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  group('首次同步引导', () {
    test('scaffold 设备配置远端后自动以远端为准，直接看到 A 的片段', () async {
      // Act
      final error = await git.configureRemote(dirB, bare);

      // Assert — 无冲突提示，B 直接拿到 A 的片段
      expect(error, isNull);
      final content = await File('$dirB/snippets.json').readAsString();
      expect(content, contains('from-A'));

      // 后续正常同步链路可用：B 新增内容能推送，A 能拉到
      await writeFile(dirB, 'from_b.txt', 'hello from B\n');
      expect(await git.commitAndPush(dirB, 'add from B'), isNull);
      expect(await git.pull(dirA), isNull);
      expect(await File('$dirA/from_b.txt').exists(), isTrue);
    });

    test('本地已有真实片段 + 远端也有数据：给出清晰提示且双方数据未丢', () async {
      // Arrange — B 本地有真实片段（非 scaffold）
      await writeFile(dirB, 'snippets.json',
          '[{"id":"b1","name":"from-B","content":"echo world"}]');
      await run('git', ['add', '-A'], cwd: dirB);
      await run('git', ['commit', '-m', 'local snippets on B'], cwd: dirB);

      // Act
      final error = await git.configureRemote(dirB, bare);

      // Assert — 可读提示，不静默覆盖
      expect(error, isNotNull);
      expect(error, contains('片段'));

      // B 本地数据未被覆盖
      final localContent = await File('$dirB/snippets.json').readAsString();
      expect(localContent, contains('from-B'));

      // 远端（A 的数据）也未被破坏
      final remoteContent =
          await run('git', ['show', 'HEAD:snippets.json'], cwd: dirA);
      expect(remoteContent.stdout as String, contains('from-A'));
    });

    test('远端还是空仓库时 configureRemote 成功，后续可正常推送', () async {
      // Arrange
      final emptyBare = '${root.path}/empty.git';
      await run('git', ['init', '--bare', emptyBare]);

      // Act
      final error = await git.configureRemote(dirB, emptyBare);

      // Assert
      expect(error, isNull);
      expect(await git.commitAndPush(dirB, 'first push from B'), isNull);
    });

    test('scaffold 判定：snippets.json 为空数组算 scaffold，有内容不算', () async {
      expect(await git.isPristineScaffold(dirB), isTrue);

      await writeFile(dirB, 'snippets.json', '[{"id":"x"}]');
      expect(await git.isPristineScaffold(dirB), isFalse);
    });
  });
}
