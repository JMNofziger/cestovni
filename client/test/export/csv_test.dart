import 'dart:convert';

import 'package:cestovni/export/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null becomes an empty field', () {
    expect(csvField(null), '');
  });

  test('booleans are lowercase true/false', () {
    expect(csvField(true), 'true');
    expect(csvField(false), 'false');
  });

  test('RFC 4180 quoting for comma, quote, and newline', () {
    expect(csvField('hello, world'), '"hello, world"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField('line\nbreak'), '"line\nbreak"');
    expect(csvField('cr\r'), '"cr\r"');
  });

  test('plain fields are unquoted', () {
    expect(csvField('Octavia'), 'Octavia');
    expect(csvField(42), '42');
  });

  test('row bytes are UTF-8 with CRLF and no BOM', () {
    final bytes = csvRowBytes(['a', null, true]);
    expect(bytes, isNot(equals(utf8Bom)));
    expect(utf8.decode(bytes), 'a,,true\r\n');
  });

  test('header bytes end in CRLF', () {
    expect(utf8.decode(csvHeaderBytes('id,name')), 'id,name\r\n');
  });

  test('UTF-8 BOM is the Excel-friendly three-byte prefix', () {
    expect(utf8Bom, [0xEF, 0xBB, 0xBF]);
  });
}
