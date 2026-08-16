/// RFC 4180 CSV helpers for CES-41.
///
/// Spec: `docs/specs/export-v1.md` § CSV rules — UTF-8 with BOM, CRLF,
/// comma delimiter, empty field = null, booleans `true`/`false`.
library;

import 'dart:convert';
import 'dart:typed_data';

/// UTF-8 BOM bytes prepended to every CSV file.
final Uint8List utf8Bom = Uint8List.fromList(const [0xEF, 0xBB, 0xBF]);

const String crlf = '\r\n';

/// Encode one field. [null] becomes empty; [bool] becomes `true`/`false`.
String csvField(Object? value) {
  if (value == null) return '';
  final String raw = value is bool
      ? (value ? 'true' : 'false')
      : value.toString();
  final bool needsQuotes = raw.contains(',') ||
      raw.contains('"') ||
      raw.contains('\n') ||
      raw.contains('\r');
  if (!needsQuotes) return raw;
  return '"${raw.replaceAll('"', '""')}"';
}

/// One CSV record including the trailing CRLF, UTF-8 encoded (no BOM).
Uint8List csvRowBytes(List<Object?> fields) {
  final String line = '${fields.map(csvField).join(',')}$crlf';
  return Uint8List.fromList(utf8.encode(line));
}

/// Header line including trailing CRLF, UTF-8 encoded (no BOM).
Uint8List csvHeaderBytes(String header) {
  return Uint8List.fromList(utf8.encode('$header$crlf'));
}
