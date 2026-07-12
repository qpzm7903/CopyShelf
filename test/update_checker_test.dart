import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:copyshelf/services/update_checker.dart';

void main() {
  group('compareVersions', () {
    test('语义比较', () {
      expect(compareVersions('0.1.20', '0.1.19'), greaterThan(0));
      expect(compareVersions('0.1.19', '0.1.20'), lessThan(0));
      expect(compareVersions('0.1.20', '0.1.20'), 0);
    });

    test('忽略 v 前缀', () {
      expect(compareVersions('v0.2.0', '0.1.9'), greaterThan(0));
    });

    test('主版本跨越', () {
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('段数不等（0.1 vs 0.1.0）', () {
      expect(compareVersions('0.1', '0.1.0'), 0);
      expect(compareVersions('0.1.1', '0.1'), greaterThan(0));
    });
  });

  group('UpdateChecker', () {
    UpdateChecker withResponse(int status, String body) => UpdateChecker(
          client: MockClient((_) async => http.Response(body, status)),
        );

    test('有新版本时 hasUpdate=true 并给出版本与链接', () async {
      final checker = withResponse(200,
          '{"tag_name": "v0.2.0", "html_url": "https://example.com/r"}');

      final result = await checker.check('0.1.20');

      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, 'v0.2.0');
      expect(result.releaseUrl, 'https://example.com/r');
    });

    test('已是最新时 hasUpdate=false', () async {
      final checker = withResponse(
          200, '{"tag_name": "v0.1.20", "html_url": "x"}');

      final result = await checker.check('0.1.20');

      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, 'v0.1.20');
    });

    test('本地更新（预发布）时 hasUpdate=false', () async {
      final checker =
          withResponse(200, '{"tag_name": "v0.1.19", "html_url": "x"}');

      final result = await checker.check('0.1.20');

      expect(result.hasUpdate, isFalse);
    });

    test('HTTP 错误返回可读 error', () async {
      final checker = withResponse(403, 'rate limited');

      final result = await checker.check('0.1.20');

      expect(result.hasUpdate, isFalse);
      expect(result.error, contains('403'));
    });

    test('缺 tag_name 返回错误', () async {
      final checker = withResponse(200, '{}');

      final result = await checker.check('0.1.20');

      expect(result.hasUpdate, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
