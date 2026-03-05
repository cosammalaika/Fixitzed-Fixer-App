import 'package:fixitzed_fixer_app/core/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeZambianNumber', () {
    test('keeps +260 unchanged', () {
      expect(normalizeZambianNumber('+260979871199'), '+260979871199');
    });

    test('converts leading 0 to +260', () {
      expect(normalizeZambianNumber('0979871199'), '+260979871199');
    });

    test('prepends +260 for 9-digit local numbers', () {
      expect(normalizeZambianNumber('979871199'), '+260979871199');
    });

    test('normalizes spaced/hyphenated numbers', () {
      expect(normalizeZambianNumber('0979 871-199'), '+260979871199');
    });
  });
}
