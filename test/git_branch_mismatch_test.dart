import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:copyshelf/services/git_service.dart';

/// bug-M1（MEDIUM）回归：本地分支名与远端默认分支不一致时，
/// pull 必须返回可读错误，而非静默成功导致各推各分支。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late GitService git;

  Future<ProcessResult> run(String exe, List<String> args,
      {String? cwd}) async {
    final r = await Process.run(exe, args, workingDirectory: cwd);
    expect(r.exitCode, 0, reason: '$exe ${args.join(' ')}: ${r.stderr}');
    return r;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'git_remote': 'bare'});
    git = GitService();
    await git.ensureInitialized();
    root = await Directory.systemTemp.createTemp('copyshelf_branch_');
  });

  tearDown(() async => root.delete(recursive: true));

  test('本地 master + 远端仅有 main：pull 返回分支不一致的可读错误', () async {
    final bare = '${root.path}/remote.git';
    final other = '${root.path}/deviceMain';
    final local = '${root.path}/deviceMaster';
    await run('git', ['init', '--bare', bare]);

    // 设备一：在 main 分支推数据到远端
    await Directory(other).create();
    await run('git', ['init', '-b', 'main', other]);
    await run('git', ['config', 'user.email', 'a@b.c'], cwd: other);
    await run('git', ['config', 'user.name', 'a'], cwd: other);
    await File('$other/snippets.json').writeAsString('["main data"]');
    await run('git', ['add', '-A'], cwd: other);
    await run('git', ['commit', '-m', 'init main'], cwd: other);
    await run('git', ['remote', 'add', 'origin', bare], cwd: other);
    await run('git', ['push', 'origin', 'main'], cwd: other);

    // 本地设备：老版 init 出 master 分支
    await Directory(local).create();
    await run('git', ['init', '-b', 'master', local]);
    await run('git', ['config', 'user.email', 'x@y.z'], cwd: local);
    await run('git', ['config', 'user.name', 'x'], cwd: local);
    await File('$local/snippets.json').writeAsString('["master data"]');
    await run('git', ['add', '-A'], cwd: local);
    await run('git', ['commit', '-m', 'init master'], cwd: local);
    await git.setRemote(local, bare);

    // Act
    final error = await git.pull(local);

    // Assert — 不再静默成功
    expect(error, isNotNull);
    expect(error, contains('master'));
    expect(error, contains('main'));
  });

  test('远端确实为空仓库时 pull 仍返回 null（不误报分支错误）', () async {
    final emptyBare = '${root.path}/empty.git';
    final local = '${root.path}/deviceC';
    await run('git', ['init', '--bare', emptyBare]);
    await Directory(local).create();
    await File('$local/snippets.json').writeAsString('[]');
    await git.init(local);
    await git.setRemote(local, emptyBare);

    expect(await git.pull(local), isNull);
  });
}
