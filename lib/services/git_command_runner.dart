import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Git 子进程执行边界：收集输出，并保证命令在超时后返回。
class GitCommandRunner {
  static const int timeoutExitCode = 124;
  static const Duration _killGrace = Duration(milliseconds: 500);

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Duration timeout,
    Map<String, String> environment = const {},
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitFuture = process.exitCode;

    try {
      final exitCode = await exitFuture.timeout(timeout);
      return ProcessResult(
        process.pid,
        exitCode,
        await stdoutFuture,
        await stderrFuture,
      );
    } on TimeoutException {
      process.kill();
      try {
        await exitFuture.timeout(_killGrace);
      } on TimeoutException {
        if (!Platform.isWindows) {
          process.kill(ProcessSignal.sigkill);
        }
      }

      final output = await stdoutFuture.timeout(
        _killGrace,
        onTimeout: () => '',
      );
      final error = await stderrFuture.timeout(_killGrace, onTimeout: () => '');
      final timeoutMessage =
          '命令执行超时（${timeout.inSeconds > 0 ? '${timeout.inSeconds}s' : '${timeout.inMilliseconds}ms'}）';
      return ProcessResult(
        process.pid,
        timeoutExitCode,
        output,
        error.trim().isEmpty ? timeoutMessage : '$error\n$timeoutMessage',
      );
    }
  }
}

/// 禁止 Git、Git Credential Manager 和 SSH 弹出交互式输入。
Map<String, String> gitNonInteractiveEnvironment({String? existingSshCommand}) {
  final ssh = existingSshCommand?.trim();
  final command = ssh == null || ssh.isEmpty ? 'ssh' : ssh;
  return {
    'GIT_TERMINAL_PROMPT': '0',
    'GCM_INTERACTIVE': 'Never',
    'GIT_SSH_COMMAND': '$command -o BatchMode=yes -o ConnectTimeout=10',
  };
}
