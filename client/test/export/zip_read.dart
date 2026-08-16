import 'dart:convert';
import 'dart:typed_data';

/// Minimal STORE-ZIP reader for CES-41 tests. Understands data
/// descriptors (GP bit 3) by taking sizes from the central directory.
Map<String, Uint8List> readStoreZip(Uint8List bytes) {
  if (bytes.length < 22) {
    throw FormatException('too small to be a ZIP (${bytes.length} bytes)');
  }
  var eocd = bytes.length - 22;
  while (eocd >= 0 && _u32(bytes, eocd) != 0x06054b50) {
    eocd--;
  }
  if (eocd < 0) throw FormatException('EOCD not found');
  final entries = _u16(bytes, eocd + 10);
  final cdOffset = _u32(bytes, eocd + 16);
  var pos = cdOffset;
  final out = <String, Uint8List>{};
  for (var i = 0; i < entries; i++) {
    if (_u32(bytes, pos) != 0x02014b50) {
      throw FormatException('bad central header at $pos');
    }
    final size = _u32(bytes, pos + 20);
    final nameLen = _u16(bytes, pos + 28);
    final extraLen = _u16(bytes, pos + 30);
    final commentLen = _u16(bytes, pos + 32);
    final localOff = _u32(bytes, pos + 42);
    final name = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLen));
    if (_u32(bytes, localOff) != 0x04034b50) {
      throw FormatException('bad local header for $name');
    }
    final lName = _u16(bytes, localOff + 26);
    final lExtra = _u16(bytes, localOff + 28);
    final dataStart = localOff + 30 + lName + lExtra;
    out[name] = Uint8List.fromList(bytes.sublist(dataStart, dataStart + size));
    pos += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);

int _u32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

/// Split a UTF-8 CSV (with BOM) into records. Trailing CRLF is dropped.
List<String> csvRecords(Uint8List bytes) {
  var text = utf8.decode(bytes);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  if (text.endsWith('\r\n')) {
    text = text.substring(0, text.length - 2);
  }
  if (text.isEmpty) return const [];
  return text.split('\r\n');
}

bool looksLikeJpeg(Uint8List bytes) =>
    bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

bool looksLikePng(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

/// RFC 4180 field split for a single record (no embedded CRLF).
List<String> parseCsvRecord(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}
