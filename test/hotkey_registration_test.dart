import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/hotkey_messages.dart';
import 'package:copyshelf/providers/snippet_provider.dart';
import 'package:copyshelf/services/paste_service.dart';

import 'helpers/mocks.dart';

void main() {
  group('HotkeyMessageDispatcher', () {
    test('注册成功消息使 registration 返回 ok', () async {
      // Arrange
      final dispatcher = HotkeyMessageDispatcher(onTriggered: () {});

      // Act
      dispatcher.handleMessage(HotkeyMessages.registeredMessage(ok: true));
      final result = await dispatcher.registration;

      // Assert
      expect(result.ok, isTrue);
      expect(result.reason, isNull);
    });

    test('注册失败返回失败原因（热键被占用）', () async {
      // Arrange
      final dispatcher = HotkeyMessageDispatcher(onTriggered: () {});

      // Act — 1409 = ERROR_HOTKEY_ALREADY_REGISTERED
      dispatcher.handleMessage(
          HotkeyMessages.registeredMessage(ok: false, errorCode: 1409));
      final result = await dispatcher.registration;

      // Assert
      expect(result.ok, isFalse);
      expect(result.reason, contains('占用'));
    });

    test('注册失败但错误码未知时给通用原因', () async {
      final dispatcher = HotkeyMessageDispatcher(onTriggered: () {});

      dispatcher.handleMessage(
          HotkeyMessages.registeredMessage(ok: false, errorCode: 5));
      final result = await dispatcher.registration;

      expect(result.ok, isFalse);
      expect(result.reason, contains('5'));
    });

    test('注册成功消息不会误触发热键回调', () async {
      // Arrange
      var triggerCount = 0;
      final dispatcher =
          HotkeyMessageDispatcher(onTriggered: () => triggerCount++);

      // Act
      dispatcher.handleMessage(HotkeyMessages.registeredMessage(ok: true));
      await dispatcher.registration;

      // Assert — 修复旧协议 bug：注册握手消息与热键触发消息必须可区分
      expect(triggerCount, 0);
    });

    test('触发消息调用 onTriggered', () {
      var triggerCount = 0;
      final dispatcher =
          HotkeyMessageDispatcher(onTriggered: () => triggerCount++);

      dispatcher.handleMessage(HotkeyMessages.triggeredMessage());
      dispatcher.handleMessage(HotkeyMessages.triggeredMessage());

      expect(triggerCount, 2);
    });

    test('未知消息被忽略且不崩溃', () async {
      var triggerCount = 0;
      final dispatcher =
          HotkeyMessageDispatcher(onTriggered: () => triggerCount++);

      dispatcher.handleMessage(null);
      dispatcher.handleMessage(true);
      dispatcher.handleMessage('junk');
      dispatcher.handleMessage({'type': 'unknown'});

      expect(triggerCount, 0);
    });

    test('等待注册结果超时返回失败', () async {
      final dispatcher = HotkeyMessageDispatcher(
        onTriggered: () {},
        registrationTimeout: const Duration(milliseconds: 20),
      );

      final result = await dispatcher.registration;

      expect(result.ok, isFalse);
      expect(result.reason, contains('超时'));
    });

    test('重复的注册消息只取第一条', () async {
      final dispatcher = HotkeyMessageDispatcher(onTriggered: () {});

      dispatcher.handleMessage(HotkeyMessages.registeredMessage(ok: true));
      dispatcher.handleMessage(
          HotkeyMessages.registeredMessage(ok: false, errorCode: 1409));
      final result = await dispatcher.registration;

      expect(result.ok, isTrue);
    });
  });

  group('SnippetProvider 热键状态', () {
    SnippetProvider buildProvider() => SnippetProvider(
          storage: MockStorageService(),
          git: MockGitService(),
          paste: (_) async => PasteOutcome.pasted,
        );

    test('setHotkeyError 后失败状态可被观察且通知监听者', () {
      // Arrange
      final provider = buildProvider();
      var notified = 0;
      provider.addListener(() => notified++);

      // Act
      provider.setHotkeyError('快捷键 Ctrl+Alt+V 注册失败：已被其他程序占用');

      // Assert
      expect(provider.hotkeyError, contains('注册失败'));
      expect(notified, 1);
    });

    test('setHotkeyError(null) 清除失败状态', () {
      final provider = buildProvider();
      provider.setHotkeyError('some error');

      provider.setHotkeyError(null);

      expect(provider.hotkeyError, isNull);
    });
  });
}
