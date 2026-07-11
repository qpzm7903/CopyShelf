import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/services/autostart_service.dart';

/// 内存版 RunKeyStore：单元测试用
class MemoryRunKeyStore implements RunKeyStore {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String command) => value = command;

  @override
  void delete() => value = null;
}

void main() {
  group('formatRunCommand', () {
    test('路径含空格时加引号', () {
      expect(
        formatRunCommand(r'C:\Program Files\CopyShelf\copyshelf.exe'),
        r'"C:\Program Files\CopyShelf\copyshelf.exe"',
      );
    });

    test('路径无空格时不加引号', () {
      expect(
        formatRunCommand(r'C:\Apps\copyshelf.exe'),
        r'C:\Apps\copyshelf.exe',
      );
    });
  });

  group('AutostartService（mock 三态往返）', () {
    late MemoryRunKeyStore store;
    late AutostartService service;

    setUp(() {
      store = MemoryRunKeyStore();
      service = AutostartService(store);
    });

    test('初始状态未启用', () {
      expect(service.isEnabled, isFalse);
    });

    test('enable 后启用且写入带引号的 exe 路径', () {
      service.enable(exePath: r'C:\Program Files\CopyShelf\copyshelf.exe');

      expect(service.isEnabled, isTrue);
      expect(store.value, r'"C:\Program Files\CopyShelf\copyshelf.exe"');
    });

    test('disable 后回到未启用', () {
      service.enable(exePath: r'C:\Apps\copyshelf.exe');

      service.disable();

      expect(service.isEnabled, isFalse);
      expect(store.value, isNull);
    });
  });

  group('WindowsRunKeyStore（真实注册表，仅 Windows CI）', () {
    test('HKCU Run 键写→读→删往返', () {
      // 用临时值名，避免污染真实 CopyShelf 配置
      final store = WindowsRunKeyStore(
        valueName: 'CopyShelfTest_${pid}',
      );
      const command = r'"C:\Temp\copyshelf test\copyshelf.exe"';

      try {
        expect(store.read(), isNull);
        store.write(command);
        expect(store.read(), command);
      } finally {
        store.delete();
      }
      expect(store.read(), isNull);
    }, skip: !Platform.isWindows ? 'win32 注册表仅在 Windows 上可测' : false);
  });
}
