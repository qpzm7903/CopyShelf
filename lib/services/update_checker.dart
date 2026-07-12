import 'dart:convert';
import 'package:http/http.dart' as http;

/// 版本比较：返回 <0 / 0 / >0，忽略 v/V 前缀，按点分段数字比较。
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .replaceAll(RegExp(r'^[vV]'), '')
      .split('.')
      .map((p) => int.tryParse(RegExp(r'^\d+').stringMatch(p) ?? '') ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// 检查更新结果
class UpdateCheckResult {
  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseUrl;
  final String? error;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
    this.error,
  });
}

/// 通过 GitHub Releases API 检查是否有新版本。
class UpdateChecker {
  /// 注入 http client（测试用 mock）
  final http.Client client;
  final String owner;
  final String repo;

  UpdateChecker({
    http.Client? client,
    this.owner = 'qpzm7903',
    this.repo = 'CopyShelf',
  }) : client = client ?? http.Client();

  Uri get _latestUri =>
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');

  /// [currentVersion] 当前应用版本（如 '0.1.20'）。
  Future<UpdateCheckResult> check(String currentVersion) async {
    try {
      final resp = await client.get(_latestUri, headers: {
        'Accept': 'application/vnd.github+json',
      });
      if (resp.statusCode != 200) {
        return UpdateCheckResult(
            hasUpdate: false, error: '检查失败（HTTP ${resp.statusCode}）');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      if (tag == null) {
        return const UpdateCheckResult(
            hasUpdate: false, error: '未找到版本信息');
      }
      final newer = compareVersions(tag, currentVersion) > 0;
      return UpdateCheckResult(
        hasUpdate: newer,
        latestVersion: tag,
        releaseUrl: json['html_url'] as String?,
      );
    } catch (e) {
      return UpdateCheckResult(hasUpdate: false, error: '检查失败：$e');
    }
  }
}
