import 'dart:io';
import 'importer.dart';

/// PowerShell（PSReadLine）历史导入。
///
/// PSReadLine 把历史逐行写入 ConsoleHost_history.txt。跨多行命令用行尾反引号续行。
/// 按命令聚合去重、取出现频次最高的 Top N 作为候选。
class PowerShellHistoryImporter extends Importer {
  /// 历史文件路径（可注入测试用样例文件）；null 时用默认位置。
  final String? historyPath;
  final int topN;

  PowerShellHistoryImporter({this.historyPath, this.topN = 50});

  @override
  String get displayName => 'PowerShell 历史';

  static const int _minLength = 2;

  @override
  Future<List<ImportCandidate>> discover() async {
    final path = historyPath ?? _defaultPath();
    if (path == null) return const [];
    final file = File(path);
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    return parseHistory(lines);
  }

  /// 解析历史行为候选（纯函数，可测试）。
  static List<ImportCandidate> parseHistory(List<String> lines,
      {int topN = 50}) {
    final commands = _foldContinuations(lines);
    final counts = <String, int>{};
    for (final cmd in commands) {
      final trimmed = cmd.trim();
      if (trimmed.length < _minLength) continue;
      counts.update(trimmed, (v) => v + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byFreq = b.value.compareTo(a.value);
        return byFreq != 0 ? byFreq : a.key.compareTo(b.key);
      });
    return entries
        .take(topN)
        .map((e) => ImportCandidate(
              name: _deriveName(e.key),
              content: e.key,
              frequency: e.value,
            ))
        .toList();
  }

  /// 合并行尾反引号续行：`git commit ` + 下一行 → 单条命令。
  static List<String> _foldContinuations(List<String> lines) {
    final result = <String>[];
    final buffer = StringBuffer();
    var continuing = false;
    for (final line in lines) {
      if (continuing) {
        buffer.write('\n');
        buffer.write(line);
      } else {
        buffer
          ..clear()
          ..write(line);
      }
      if (line.endsWith('`')) {
        // 去掉续行反引号，标记继续
        final s = buffer.toString();
        buffer
          ..clear()
          ..write(s.substring(0, s.length - 1));
        continuing = true;
      } else {
        result.add(buffer.toString());
        continuing = false;
      }
    }
    if (continuing) result.add(buffer.toString());
    return result;
  }

  /// 用命令首个词作为片段名（截断过长的）。
  static String _deriveName(String command) {
    final firstLine = command.split('\n').first.trim();
    final maxLen = 40;
    return firstLine.length <= maxLen
        ? firstLine
        : '${firstLine.substring(0, maxLen)}…';
  }

  String? _defaultPath() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return '$appData\\Microsoft\\Windows\\PowerShell\\PSReadLine'
        '\\ConsoleHost_history.txt';
  }
}
