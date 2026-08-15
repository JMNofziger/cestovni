/// Deterministic JPEG fixtures for the receipt-photo pipeline tests.
///
/// Fixtures are generated in memory rather than committed as binaries: the
/// repo is deliberately binary-free (see the `google_fonts` note in
/// `client/pubspec.yaml`), and a generated fixture lets each test state
/// exactly which sensitive tags it expects the pipeline to remove.
///
/// Pointer for the spec's `tests/photos/` location: `tests/photos/README.md`.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// EXIF `DateTimeOriginal` baked into [jpegWithSensitiveExif].
const String fixtureExifDateTimeOriginal = '2026:03:04 09:15:00';

/// The same instant as a naive wall-clock reading. Tests convert this the
/// same way the pipeline does, so assertions hold in any machine timezone.
final DateTime fixtureExifNaiveCaptureTime = DateTime(2026, 3, 4, 9, 15, 0);

/// Tags the pipeline must remove, as `(ifd, tagName)` pairs.
const List<(String, String)> sensitiveFixtureTags = [
  ('gps', 'GPSLatitudeRef'),
  ('gps', 'GPSLatitude'),
  ('gps', 'GPSLongitudeRef'),
  ('gps', 'GPSLongitude'),
  ('image', 'Make'),
  ('image', 'Model'),
  ('image', 'Software'),
  ('image', 'Artist'),
  ('exif', 'MakerNote'),
  ('exif', 'BodySerialNumber'),
  ('exif', 'LensSerialNumber'),
  ('exif', 'CameraOwnerName'),
];

/// A landscape JPEG carrying GPS coordinates, maker notes, camera and lens
/// serial numbers, owner name, software fingerprint, and a capture time.
Uint8List jpegWithSensitiveExif({
  int width = 2400,
  int height = 1600,
  int? orientation,
  String dateTimeOriginal = fixtureExifDateTimeOriginal,
  String? offsetTimeOriginal,
}) {
  final image = _receiptLikeImage(width, height);
  final exif = image.exif;

  exif.imageIfd['Make'] = 'ACME';
  exif.imageIfd['Model'] = 'Phone 9 Pro';
  exif.imageIfd['Software'] = 'ACME Camera 3.2.1';
  exif.imageIfd['Artist'] = 'Fixture Owner';
  if (orientation != null) exif.imageIfd.orientation = orientation;

  exif.exifIfd['DateTimeOriginal'] = dateTimeOriginal;
  if (offsetTimeOriginal != null) {
    exif.exifIfd['OffsetTimeOriginal'] = offsetTimeOriginal;
  }
  exif.exifIfd['CameraOwnerName'] = 'Fixture Owner';
  exif.exifIfd['BodySerialNumber'] = 'BODY-SN-123456';
  exif.exifIfd['LensSerialNumber'] = 'LENS-SN-654321';
  exif.exifIfd['MakerNote'] =
      img.IfdValueUndefined.list(const [0xAC, 0x4D, 0x45, 0x01, 0x02, 0x03]);

  // 50°05'00" N, 14°25'00" E — GPS tags declare no fixed type in the image
  // package's tag table, so the values are built explicitly.
  exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  exif.gpsIfd['GPSLatitude'] = _rationals(const [
    [50, 1],
    [5, 1],
    [0, 1],
  ]);
  exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
  exif.gpsIfd['GPSLongitude'] = _rationals(const [
    [14, 1],
    [25, 1],
    [0, 1],
  ]);

  return img.encodeJpg(image, quality: 92);
}

/// A JPEG with no EXIF block at all — the capture-time fallback case.
Uint8List jpegWithoutExif({int width = 800, int height = 600}) =>
    img.encodeJpg(_receiptLikeImage(width, height), quality: 92);

/// Bytes that are not a decodable image.
Uint8List notAnImage() =>
    Uint8List.fromList('this is not a jpeg'.codeUnits);

/// Reads a tag out of an encoded JPEG, or null when it is absent.
img.IfdValue? readTag(Uint8List jpeg, String ifd, String tagName) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) return null;
  final exif = decoded.exif;
  final directory = switch (ifd) {
    'gps' => exif.gpsIfd,
    'exif' => exif.exifIfd,
    'image' => exif.imageIfd,
    _ => throw ArgumentError.value(ifd, 'ifd', 'unknown IFD'),
  };
  return directory[tagName];
}

/// Pale background with darker bands, so the encoder has real detail to
/// compress and a resize is observable.
img.Image _receiptLikeImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(238, 234, 224));
  final band = (height / 12).round().clamp(1, height);
  for (var y = band; y + band < height; y += band * 2) {
    img.fillRect(
      image,
      x1: (width * 0.08).round(),
      y1: y,
      x2: (width * 0.92).round(),
      y2: y + (band / 2).round(),
      color: img.ColorRgb8(52, 48, 44),
    );
  }
  return image;
}

img.IfdValue _rationals(List<List<int>> pairs) {
  final bytes = Uint8List(pairs.length * 8);
  final view = ByteData.view(bytes.buffer);
  for (var i = 0; i < pairs.length; i++) {
    view.setUint32(i * 8, pairs[i][0]);
    view.setUint32(i * 8 + 4, pairs[i][1]);
  }
  return img.IfdValueRational.data(
    img.InputBuffer(bytes, bigEndian: true),
    pairs.length,
  );
}
