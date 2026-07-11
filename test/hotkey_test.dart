import 'package:flutter_test/flutter_test.dart';
import 'package:copyshelf/utils/hotkey.dart';

void main() {
  group('Hotkey', () {
    test('parse / format roundtrip', () {
      final hotkey = Hotkey.parse('Ctrl+Alt+V');
      expect(hotkey, isNotNull);
      expect(hotkey!.format(), 'Ctrl+Alt+V');
      expect(hotkey.ctrl, isTrue);
      expect(hotkey.alt, isTrue);
      expect(hotkey.shift, isFalse);
      expect(hotkey.key, 'V');
    });

    test('parse is case/space tolerant', () {
      final hotkey = Hotkey.parse(' ctrl + shift + p ');
      expect(hotkey, isNotNull);
      expect(hotkey!.format(), 'Ctrl+Shift+P');
    });

    test('modifiers bitmask matches win32 MOD_* values', () {
      expect(Hotkey.parse('Ctrl+Alt+V')!.modifiers, 0x0002 | 0x0001);
      expect(Hotkey.parse('Win+Shift+A')!.modifiers, 0x0008 | 0x0004);
    });

    test('virtualKey for letters, digits, and F-keys', () {
      expect(Hotkey.parse('Ctrl+V')!.virtualKey, 0x56);
      expect(Hotkey.parse('Ctrl+0')!.virtualKey, 0x30);
      expect(Hotkey.parse('Ctrl+F1')!.virtualKey, 0x70);
      expect(Hotkey.parse('Ctrl+F12')!.virtualKey, 0x7B);
    });

    test('rejects shift-only and bare keys (would clash with typing)', () {
      expect(Hotkey.parse('Shift+V'), isNull);
      expect(Hotkey.parse('V'), isNull);
    });

    test('rejects unsupported main keys and double main keys', () {
      expect(Hotkey.parse('Ctrl+Alt+F13'), isNull);
      expect(Hotkey.parse('Ctrl+Alt+VV'), isNull);
      expect(Hotkey.parse('Ctrl+A+B'), isNull);
      expect(Hotkey.parse(''), isNull);
    });

    test('parts for keycap rendering keeps canonical order', () {
      expect(Hotkey.parse('alt+win+ctrl+x')!.parts, ['Ctrl', 'Alt', 'Win', 'X']);
    });

    test('default hotkey is Ctrl+Alt+V', () {
      expect(Hotkey.defaultHotkey.format(), 'Ctrl+Alt+V');
      expect(Hotkey.defaultHotkey.isValid, isTrue);
    });
  });
}
