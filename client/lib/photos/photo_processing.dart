/// Receipt-photo byte pipeline — the single audit point for EXIF privacy.
///
/// Spec: `docs/specs/photo-pipeline.md` §"Capture pipeline" +
/// `docs/specs/platform-compliance-v1.md` §receipt photos.
///
/// Pure module: no Flutter, no Drift, no file IO. Everything here works on
/// in-memory bytes so the privacy behaviour is testable without a camera,
/// a device, or a database. Persistence lives in `photo_store.dart` /
/// `photo_service.dart`.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Long edge of the stored JPEG. 1 600 px keeps receipt text legible while
/// holding a single photo near ~150–250 KB (spec §"Capture pipeline").
const int photoLongEdgePx = 1600;

/// JPEG quality of the stored file.
const int photoJpegQuality = 80;

/// Raised when the incoming bytes are not an image we can decode. The Log
/// form must stay usable, so callers surface this and carry on.
class PhotoProcessingException implements Exception {
  const PhotoProcessingException(this.message);

  final String message;

  @override
  String toString() => 'PhotoProcessingException: $message';
}

/// Result of [processPhotoBytes] — everything needed to write the file and
/// the `photo_refs` row, and nothing else. The original bytes are dropped.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.bytes,
    required this.sha256Hex,
    required this.capturedAt,
    required this.capturedAtFromExif,
    required this.width,
    required this.height,
  });

  /// Stripped, resized, recompressed JPEG.
  final Uint8List bytes;

  /// Hex SHA-256 of [bytes] — integrity check on read.
  final String sha256Hex;

  /// Capture time in UTC. Derived from EXIF when the camera recorded one,
  /// otherwise the caller-supplied clock reading.
  final DateTime capturedAt;

  /// False when [capturedAt] came from the device clock rather than EXIF.
  final bool capturedAtFromExif;

  final int width;
  final int height;

  int get byteSize => bytes.length;
}

/// Runs the full capture pipeline over [input]:
///
/// 1. decode
/// 2. bake the EXIF orientation into the pixels
/// 3. resize the long edge down to [photoLongEdgePx] (never upscales)
/// 4. re-encode as JPEG q[photoJpegQuality] with **no** EXIF block at all
/// 5. hash the result
///
/// Step 4 is the privacy guarantee: rather than deleting a hard-list of
/// sensitive tags and hoping the list is complete, the output carries an
/// empty [img.ExifData], so GPS, maker notes, serial numbers, owner name and
/// software fingerprints cannot survive by omission from a blocklist. The
/// only metadata that outlives this call is [ProcessedPhoto.capturedAt],
/// which the caller persists in `photo_refs.captured_at`.
///
/// [now] supplies the capture-time fallback when the source has no EXIF
/// timestamp; callers inject it so tests are deterministic.
ProcessedPhoto processPhotoBytes(
  Uint8List input, {
  required DateTime now,
}) {
  if (input.isEmpty) {
    throw const PhotoProcessingException('Image was empty.');
  }

  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw const PhotoProcessingException('Unsupported or corrupt image.');
  }

  final capturedAtFromExif = readExifCaptureTime(decoded.exif);

  // Orientation must be applied while the tag is still around; afterwards
  // the tag is meaningless because the pixels already match it.
  final upright = img.bakeOrientation(decoded);
  final resized = _resizeToLongEdge(upright, photoLongEdgePx);

  // Fresh, empty container — never a filtered copy of the source EXIF.
  resized.exif = img.ExifData();

  final bytes = img.encodeJpg(resized, quality: photoJpegQuality);
  final digest = sha256.convert(bytes);

  return ProcessedPhoto(
    bytes: bytes,
    sha256Hex: digest.toString(),
    capturedAt: capturedAtFromExif ?? now.toUtc(),
    capturedAtFromExif: capturedAtFromExif != null,
    width: resized.width,
    height: resized.height,
  );
}

img.Image _resizeToLongEdge(img.Image image, int longEdge) {
  final currentLongEdge =
      image.width >= image.height ? image.width : image.height;
  if (currentLongEdge <= longEdge) return image;

  return image.width >= image.height
      ? img.copyResize(image, width: longEdge)
      : img.copyResize(image, height: longEdge);
}

/// EXIF capture time in UTC, or null when the source has none.
///
/// `DateTimeOriginal` (fallback `DateTime`) is a naive wall-clock reading in
/// the camera's own zone. When the camera also recorded `OffsetTimeOriginal`
/// (EXIF 2.31+, e.g. `+02:00`) that offset is authoritative; otherwise the
/// reading is interpreted in the device's local zone, which is the best
/// available guess for a phone photographing a receipt.
DateTime? readExifCaptureTime(img.ExifData exif) {
  final raw = exif.exifIfd['DateTimeOriginal']?.toString() ??
      exif.imageIfd['DateTime']?.toString();
  if (raw == null) return null;

  final naive = _parseExifDateTime(raw.trim());
  if (naive == null) return null;

  final offset = _parseExifOffset(
    exif.exifIfd['OffsetTimeOriginal']?.toString().trim(),
  );
  if (offset != null) {
    return DateTime.utc(
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    ).subtract(offset);
  }

  return DateTime(
    naive.year,
    naive.month,
    naive.day,
    naive.hour,
    naive.minute,
    naive.second,
  ).toUtc();
}

/// EXIF stores timestamps as `YYYY:MM:DD HH:MM:SS`.
final _exifDateTimePattern =
    RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})');

DateTime? _parseExifDateTime(String raw) {
  final match = _exifDateTimePattern.firstMatch(raw);
  if (match == null) return null;
  try {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } on FormatException {
    return null;
  }
}

final _exifOffsetPattern = RegExp(r'^([+-])(\d{2}):(\d{2})$');

Duration? _parseExifOffset(String? raw) {
  if (raw == null) return null;
  final match = _exifOffsetPattern.firstMatch(raw);
  if (match == null) return null;
  final magnitude = Duration(
    hours: int.parse(match.group(2)!),
    minutes: int.parse(match.group(3)!),
  );
  return match.group(1) == '-' ? -magnitude : magnitude;
}
