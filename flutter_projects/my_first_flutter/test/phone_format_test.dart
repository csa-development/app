import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/services/phone_format.dart';

void main() {
  group('canonicalPhone', () {
    test('every spelling of the same Ghana number matches', () {
      const spellings = [
        '+233244123456',
        '0244123456',
        '00233244123456',
        '233244123456',
        '+233 24 412 3456',
        '024-412-3456',
        '(0244) 123456',
      ];
      for (final s in spellings) {
        expect(canonicalPhone(s), '233244123456', reason: s);
      }
    });

    test('different numbers do not match', () {
      expect(canonicalPhone('+233244123456'),
          isNot(canonicalPhone('+233244123457')));
      expect(canonicalPhone('+233244123456'),
          isNot(canonicalPhone('+234244123456')));
    });

    test('empty stays empty', () {
      expect(canonicalPhone(''), '');
      expect(canonicalPhone('   '), '');
    });
  });

  group('splitStoredPhone', () {
    test('international Ghana number', () {
      final p = splitStoredPhone('+233244123456');
      expect(p.isoCode, 'GH');
      expect(p.national, '244123456');
    });

    test('older local-format Ghana number shows as Ghana', () {
      final p = splitStoredPhone('0244123456');
      expect(p.isoCode, 'GH');
      expect(p.national, '244123456');
    });

    test('another country keeps its own flag', () {
      final p = splitStoredPhone('+2348012345678');
      expect(p.isoCode, 'NG');
      expect(p.national, '8012345678');
    });

    test('empty gives an empty Ghana field', () {
      final p = splitStoredPhone('');
      expect(p.isoCode, 'GH');
      expect(p.national, '');
    });

    test('an unknown country code does not crash', () {
      final p = splitStoredPhone('+99912345');
      expect(p.isoCode, 'GH');
      expect(p.national, isNotEmpty);
    });
  });
}
