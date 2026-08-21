/// Central-directory ZIP reader for CES-70 import.
///
/// Spec: `docs/specs/export-import.md` § Input contract → ZIP shape.
///
/// Sizes come from the **central directory**, never the local headers:
/// CES-41 writes with the data-descriptor flag (GP bit 3) set, so the
/// local-header CRC and size fields are zero. Promoted from the CES-41
/// test helper `client/test/export/zip_read.dart`, which already got
/// this right, and extended with DEFLATE support.
///
/// Our own exports are always STORE. DEFLATE is accepted defensively so
/// an archive that passed through a cloud-storage tool still opens; the
/// inflate callback is **injected** so this file stays pure (no
/// `dart:io`, no Flutter, no Drift).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'import_errors.dart';

/// Raw-DEFLATE inflater. [expectedSize] is the uncompressed length from
/// the central directory, for implementations that want to pre-size.
typedef Inflate = Uint8List Function(Uint8List deflated, int expectedSize);

const int _methodStore = 0;
const int _methodDeflate = 8;

const int _sigEocd = 0x06054b50;
const int _sigCentral = 0x02014b50;
const int _sigLocal = 0x04034b50;

/// Decoded ZIP entries by name, in central-directory order.
///
/// Directory entries (names ending in `/`) are skipped. Throws
/// [ImportException] with [ImportErrorCode.notAZip] on any structural
/// problem — a truncated file, a missing EOCD, a bad signature, or a
/// compression method we do not support.
Map<String, Uint8List> readZipEntries(
  Uint8List bytes, {
  Inflate? inflate,
}) {
  final eocd = _findEocd(bytes);
  final entryCount = _u16(bytes, eocd + 10);
  final cdOffset = _u32(bytes, eocd + 16);
  if (cdOffset >= bytes.length) {
    throw const ImportException(
      ImportErrorCode.notAZip,
      'Central directory offset is outside the file.',
    );
  }

  final out = <String, Uint8List>{};
  var pos = cdOffset;
  for (var i = 0; i < entryCount; i++) {
    if (pos + 46 > bytes.length || _u32(bytes, pos) != _sigCentral) {
      throw const ImportException(
        ImportErrorCode.notAZip,
        'Damaged central directory entry.',
      );
    }
    final method = _u16(bytes, pos + 10);
    final compressedSize = _u32(bytes, pos + 20);
    final uncompressedSize = _u32(bytes, pos + 24);
    final nameLen = _u16(bytes, pos + 28);
    final extraLen = _u16(bytes, pos + 30);
    final commentLen = _u16(bytes, pos + 32);
    final localOffset = _u32(bytes, pos + 42);

    if (pos + 46 + nameLen > bytes.length) {
      throw const ImportException(
        ImportErrorCode.notAZip,
        'Entry name runs past the end of the file.',
      );
    }
    final name = _decodeName(bytes, pos + 46, nameLen);

    if (!name.endsWith('/')) {
      out[name] = _readEntryData(
        bytes,
        name: name,
        localOffset: localOffset,
        method: method,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        inflate: inflate,
      );
    }

    pos += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

Uint8List _readEntryData(
  Uint8List bytes, {
  required String name,
  required int localOffset,
  required int method,
  required int compressedSize,
  required int uncompressedSize,
  required Inflate? inflate,
}) {
  if (localOffset + 30 > bytes.length ||
      _u32(bytes, localOffset) != _sigLocal) {
    throw ImportException(
      ImportErrorCode.notAZip,
      'Damaged local header for "$name".',
    );
  }
  final localNameLen = _u16(bytes, localOffset + 26);
  final localExtraLen = _u16(bytes, localOffset + 28);
  final start = localOffset + 30 + localNameLen + localExtraLen;
  final end = start + compressedSize;
  if (start > bytes.length || end > bytes.length) {
    throw ImportException(
      ImportErrorCode.notAZip,
      'Entry "$name" is truncated.',
    );
  }
  final raw = Uint8List.sublistView(bytes, start, end);

  switch (method) {
    case _methodStore:
      return Uint8List.fromList(raw);
    case _methodDeflate:
      if (inflate == null) {
        throw ImportException(
          ImportErrorCode.notAZip,
          'Entry "$name" is DEFLATE-compressed and no inflater was '
          'provided.',
        );
      }
      final result = inflate(Uint8List.fromList(raw), uncompressedSize);
      if (uncompressedSize != 0 && result.length != uncompressedSize) {
        throw ImportException(
          ImportErrorCode.notAZip,
          'Entry "$name" did not decompress to its declared size.',
        );
      }
      return result;
    default:
      throw ImportException(
        ImportErrorCode.notAZip,
        'Entry "$name" uses an unsupported compression method ($method).',
      );
  }
}

/// Scan backwards for the end-of-central-directory record. Scanning from
/// the tail is required because the record is followed by a
/// variable-length comment; we additionally check the declared comment
/// length so a byte sequence inside a comment cannot masquerade as EOCD.
int _findEocd(Uint8List bytes) {
  if (bytes.length < 22) {
    throw const ImportException(
      ImportErrorCode.notAZip,
      'File is too small to be a ZIP archive.',
    );
  }
  for (var i = bytes.length - 22; i >= 0; i--) {
    if (_u32(bytes, i) != _sigEocd) continue;
    final commentLen = _u16(bytes, i + 20);
    if (i + 22 + commentLen == bytes.length) return i;
  }
  throw const ImportException(
    ImportErrorCode.notAZip,
    'Not a ZIP archive (no end-of-central-directory record).',
  );
}

String _decodeName(Uint8List bytes, int offset, int length) {
  try {
    return utf8.decode(Uint8List.sublistView(bytes, offset, offset + length));
  } on FormatException {
    throw const ImportException(
      ImportErrorCode.notAZip,
      'Entry name is not valid UTF-8.',
    );
  }
}

int _u16(Uint8List b, int o) {
  if (o + 2 > b.length) {
    throw const ImportException(
      ImportErrorCode.notAZip,
      'Unexpected end of archive.',
    );
  }
  return b[o] | (b[o + 1] << 8);
}

int _u32(Uint8List b, int o) {
  if (o + 4 > b.length) {
    throw const ImportException(
      ImportErrorCode.notAZip,
      'Unexpected end of archive.',
    );
  }
  return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
}
