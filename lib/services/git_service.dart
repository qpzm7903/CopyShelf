import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Git 同步服务
///
/// 管理数据目录内的 Git 仓库操作：
/// - 首次使用时自动 git init
/// - 增删改片段后自动 commit，push 前先 pull --rebase
/// - 应用启动时自动 pull --rebase
/// - 设置页可手动「立即同步」（pull）
/// - 冲突时 rebase --abort 保持本地可用，反馈用户手动处理
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

  /// 测试用：配合 SharedPreferences.setMockInitialValues 使用
  @visibleForTesting
  Future<void> ensureInitialized() => _init();

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

  /// 当前分支名（探测而非硬编码：git init 的默认分支因环境而异）
  Future<String> _currentBranch(String dataDir) async {
    final result = await _git(dataDir, ['rev-parse', '--abbrev-ref', 'HEAD']);
    if (result.exitCode != 0) return 'master';
    final branch = (result.stdout as String).trim();
    return branch.isEmpty ? 'master' : branch;
  }

  /// 初始化 Git 仓库（如果尚无 `.git`）
  Future<void> init(String dataDir) async {
    final dotGit = Directory('$dataDir${Platform.pathSeparator}.git');
    if (await dotGit.exists()) return;

    await _git(dataDir, ['init']);
    // 设置默认用户信息（仅用于本地 commit）
    await _git(dataDir, ['config', 'user.name', 'copyshelf']);
    await _git(dataDir, ['config', 'user.email', 'copyshelf@local']);

    // 初始 commit
    await _git(dataDir, ['add', '-A']);
    await _git(dataDir, ['commit', '-m', 'init copyshelf']);
  }

  /// 关联远程仓库
  Future<void> setRemote(String dataDir, String remoteUrl) async {
    // 先移除已有 remote（如果有）
    await _git(dataDir, ['remote', 'remove', 'origin']);
    await _git(dataDir, ['remote', 'add', 'origin', remoteUrl]);
  }

  /// 拉取远端变更（pull --rebase）
  ///
  /// 返回 null 表示成功（或无需拉取），非 null 为用户可读的错误信息。
  /// 冲突时自动 rebase --abort，保证本地仓库仍可正常增删改（不阻塞本地编辑）。
  Future<String?> pull(String dataDir) async {
    if (_gitRemote == null) return null;

    final branch = await _currentBranch(dataDir);
    final result = await _git(dataDir, ['pull', '--rebase', 'origin', branch]);
    if (result.exitCode != 0) {
      final stderr = result.stderr as String? ?? '';
      final stdout = result.stdout as String? ?? '';
      final output = '$stdout\n$stderr';
      // 如果只是没有远程分支（远端还是空仓库），不算错误
      if (output.contains("couldn't find remote ref")) {
        return null;
      }
      if (output.contains('conflict') || output.contains('CONFLICT')) {
        // 中止 rebase，让本地保持可用状态（不阻塞本地编辑）
        await _git(dataDir, ['rebase', '--abort']);
        return 'Git 同步冲突：远端和本地修改了同一条片段。'
            '本地编辑不受影响，请到数据目录手动解决后再同步：\n$dataDir';
      }
      return 'Git pull 失败：${stderr.trim()}';
    }
    return null;
  }

  /// 提交并推送本地变更（push 前先 pull --rebase）
  ///
  /// 返回 null 表示成功，返回非 null 字符串表示错误信息。
  Future<String?> commitAndPush(String dataDir, String message) async {
    try {
      await _git(dataDir, ['add', '-A']);

      // 检查是否有变更需要 commit
      final status = await _git(dataDir, ['status', '--porcelain']);
      if ((status.stdout as String).trim().isNotEmpty) {
        await _git(dataDir, ['commit', '-m', message]);
      }

      if (_gitRemote == null) return null;

      // push 前先拉取远端，避免 non-fast-forward 被拒
      final pullError = await pull(dataDir);
      if (pullError != null) return pullError;

      final branch = await _currentBranch(dataDir);
      final result = await _git(dataDir, ['push', 'origin', branch]);
      if (result.exitCode != 0) {
        final stderr = result.stderr as String? ?? '';
        return 'Git push 失败：${stderr.trim()}';
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
    return commitAndPush(dataDir, 'sync on startup');
  }
}
