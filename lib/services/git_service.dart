import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Git 同步服务
///
/// 管理数据目录内的 Git 仓库操作：
/// - 首次使用时自动 git init
/// - 每次增删改指令后自动 commit
/// - 每次 commit 后自动 push
/// - 应用启动时自动 pull --rebase
/// - 冲突时反馈用户手动处理
class GitService {
  static GitService? _instance;

  SharedPreferences? _prefs;
  bool _initialized = false;

  @visibleForTesting
  GitService();

  static Future<GitService> get instance async {
    if (_instance != null) return _instance!;
    final service = GitService();
    await service._init();
    _instance = service;
    return service;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('GitService 尚未初始化。');
    }
    return p;
  }

  String? get _gitRemote => _p.getString(AppConstants.prefKeyGitRemote);

  /// 在数据目录内执行 git 命令
  Future<ProcessResult> _git(String dir, List<String> args) async {
    return Process.run('git', args,
        workingDirectory: dir,
        runInShell: true,
        stdoutEncoding: utf8,
        stderrEncoding: utf8);
  }

  /// 初始化 Git 仓库（如果尚无 `.git`）
  Future<void> init(String dataDir) async {
    final dotGit = Directory('$dataDir\\.git');
    if (await dotGit.exists()) return;

    await _git(dataDir, ['init']);
    // 设置默认用户信息（仅用于本地 commit）
    await _git(dataDir, ['config', 'user.name', 'copyshelf']);
    await _git(dataDir, ['config', 'user.email', 'copyshelf@local']);

    // 初始 commit
    await _git(dataDir, ['add', '-A']);
    await _git(dataDir, ['commit', '-m', 'chore: init copyshelf']);
  }

  /// 关联远程仓库
  Future<void> setRemote(String dataDir, String remoteUrl) async {
    // 先移除已有 remote（如果有）
    await _git(dataDir, ['remote', 'remove', 'origin']);
    await _git(dataDir, ['remote', 'add', 'origin', remoteUrl]);
  }

  /// 拉取远端变更（pull --rebase）
  ///
  /// 返回 null 表示成功，返回非 null 字符串表示冲突信息。
  Future<String?> pull(String dataDir) async {
    if (_gitRemote == null) return null;

    final result = await _git(dataDir, ['pull', '--rebase', 'origin', 'master']);
    if (result.exitCode != 0) {
      final stderr = result.stderr as String? ?? '';
      if (stderr.contains('conflict')) {
        return 'Git 同步冲突：远端和本地有冲突，请手动解决后重启应用。\n\n$stderr';
      }
      // 如果只是没有远程分支，不算错误
      if (stderr.contains('couldn\'t find remote ref')) {
        return null;
      }
      return 'Git pull 失败：$stderr';
    }
    return null;
  }

  /// 提交并推送本地变更
  ///
  /// 返回 null 表示成功，返回非 null 字符串表示错误信息。
  Future<String?> commitAndPush(String dataDir, String message) async {
    try {
      await _git(dataDir, ['add', '-A']);

      // 检查是否有变更需要 commit
      final status = await _git(dataDir, ['status', '--porcelain']);
      if ((status.stdout as String).trim().isEmpty) {
        return null; // 无变更，无需 commit
      }

      var result = await _git(dataDir, ['commit', '-m', message]);
      if (result.exitCode != 0 && !(result.stderr as String).contains('nothing to commit')) {
        // commit 失败但不阻塞
      }

      // push
      if (_gitRemote != null) {
        result = await _git(dataDir, ['push', 'origin', 'master']);
        if (result.exitCode != 0) {
          final stderr = result.stderr as String? ?? '';
          return 'Git push 失败：$stderr';
        }
      }

      return null;
    } catch (e) {
      return 'Git 操作异常：$e';
    }
  }

  /// 启动时完整同步（pull 后推本地变更）
  Future<String?> syncOnStart(String dataDir) async {
    final pullError = await pull(dataDir);
    if (pullError != null) return pullError;

    // 拉取后可能已合并远端变更，推送本地提交
    return commitAndPush(dataDir, 'chore: sync on startup');
  }
}
