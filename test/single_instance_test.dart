import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/single_instance_service.dart';

void main() {
  group('SingleInstanceService（真实 localhost socket）', () {
    late SingleInstanceService first;

    setUp(() {
      first = SingleInstanceService();
    });

    tearDown(() async {
      await first.dispose();
    });

    test('首实例抢锁成功', () async {
      // Act — port 0 让系统分配空闲端口
      final acquired = await first.tryAcquire(port: 0, onWake: () async {});

      // Assert
      expect(acquired, isTrue);
      expect(first.port, greaterThan(0));
    });

    test('端口已被占用时第二个实例抢锁失败', () async {
      // Arrange
      await first.tryAcquire(port: 0, onWake: () async {});
      final second = SingleInstanceService();

      // Act
      final acquired =
          await second.tryAcquire(port: first.port!, onWake: () async {});

      // Assert
      expect(acquired, isFalse);
      await second.dispose();
    });

    test('notifyExisting 发送 wake 指令触发首实例唤醒回调', () async {
      // Arrange
      final woken = Completer<void>();
      await first.tryAcquire(port: 0, onWake: () async {
        if (!woken.isCompleted) woken.complete();
      });

      // Act
      final delivered =
          await SingleInstanceService.notifyExisting(port: first.port!);

      // Assert
      expect(delivered, isTrue);
      await woken.future.timeout(const Duration(seconds: 2));
    });

    test('无监听实例时 notifyExisting 返回 false', () async {
      // Arrange — 先占端口再释放，确保端口无人监听
      await first.tryAcquire(port: 0, onWake: () async {});
      final freePort = first.port!;
      await first.dispose();

      // Act
      final delivered =
          await SingleInstanceService.notifyExisting(port: freePort);

      // Assert
      expect(delivered, isFalse);
    });

    test('非 wake 指令的垃圾数据不触发唤醒回调', () async {
      // Arrange
      var wakeCount = 0;
      await first.tryAcquire(port: 0, onWake: () async => wakeCount++);

      // Act
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, first.port!);
      socket.write('junk-data\n');
      await socket.flush();
      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(wakeCount, 0);
    });

    test('dispose 后端口可被重新绑定', () async {
      // Arrange
      await first.tryAcquire(port: 0, onWake: () async {});
      final port = first.port!;
      await first.dispose();

      // Act
      final second = SingleInstanceService();
      final acquired = await second.tryAcquire(port: port, onWake: () async {});

      // Assert
      expect(acquired, isTrue);
      await second.dispose();
    });

    test('CopyShelf 实例回 ack → notifyExisting 返回 true（bug-M1）', () async {
      await first.tryAcquire(port: 0, onWake: () async {});

      final delivered =
          await SingleInstanceService.notifyExisting(port: first.port!);

      expect(delivered, isTrue);
    });

    test('陌生程序占端口但不回 ack → notifyExisting 返回 false（bug-M1）', () async {
      // Arrange — 模拟一个碰巧占用端口、只 accept 不回 ack 的陌生服务
      final stranger =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      stranger.listen((client) {
        // 读取但从不回 copyshelf-ack
        client.listen((_) {}, onError: (_) {});
      });

      // Act
      final delivered =
          await SingleInstanceService.notifyExisting(port: stranger.port);

      // Assert — 收不到 ack，判定对端不是 CopyShelf
      expect(delivered, isFalse);
      await stranger.close();
    });
  });
}
