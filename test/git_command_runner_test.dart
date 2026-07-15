import 'dart:io';

import 'package:copyshelf/services/git_command_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slow process is terminated when the command timeout expires', () async {
    final runner = GitCommandRunner();
    final stopwatch = Stopwatch()..start();
    final executable = Platform.isWindows ? 'powershell.exe' : '/bin/sh';
    final arguments = Platform.isWindows
        ? ['-NoProfile', '-Command', 'Start-Sleep -Seconds 5']
        : ['-c', 'sleep 5'];

    final result = await runner.run(
      executable,
      arguments,
      workingDirectory: Directory.current.path,
      timeout: const Duration(milliseconds: 80),
    );
    stopwatch.stop();

    expect(result.exitCode, GitCommandRunner.timeoutExitCode);
    expect(result.stderr, contains('超时'));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('git environment disables credential and SSH interaction', () {
    final environment = gitNonInteractiveEnvironment(
      existingSshCommand: 'ssh -i custom-key',
    );

    expect(environment['GIT_TERMINAL_PROMPT'], '0');
    expect(environment['GCM_INTERACTIVE'], 'Never');
    expect(environment['GIT_SSH_COMMAND'], contains('ssh -i custom-key'));
    expect(environment['GIT_SSH_COMMAND'], contains('BatchMode=yes'));
    expect(environment['GIT_SSH_COMMAND'], contains('ConnectTimeout=10'));
  });
}
