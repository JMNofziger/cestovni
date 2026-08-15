/// EXIF-strip and resize behaviour of the receipt-photo pipeline.
///
/// Spec: `docs/specs/photo-pipeline.md` §"Capture pipeline" + §"Test
/// expectations" item 1.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cestovni/photos/photo_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12, 0, 0);

  group('EXIF stripping', () {
    test('fixture really carries the sensitive tags before processing', () {
      final input = jpegWithSensitiveExif();

      for (final (ifd, tag) in sensitiveFixtureTags) {
        expect(
          readTag(input, ifd, tag),
          isNotNull,
          reason: 'fixture must contain $ifd.$tag or the strip assertion '
              'below proves nothing',
        );
      }
    });

    test('output carries none of the stripped tags', () {
      final processed = processPhotoBytes(jpegWithSensitiveExif(), now: now);

      for (final (ifd, tag) in sensitiveFixtureTags) {
        expect(
          readTag(processed.bytes, ifd, tag),
          isNull,
          reason: '$ifd.$tag survived the pipeline',
        );
      }
    });

    test('output has no EXIF block at all', () {
      final processed = processPhotoBytes(jpegWithSensitiveExif(), now: now);

      final decoded = img.decodeJpg(processed.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.exif.isEmpty, isTrue,
          reason: 'the stored JPEG must carry an empty EXIF container, not a '
              'filtered copy of the source');
    });

    test('serial numbers do not survive anywhere in the stored bytes', () {
      final processed = processPhotoBytes(jpegWithSensitiveExif(), now: now);

      for (final secret in const [
        'BODY-SN-123456',
        'LENS-SN-654321',
        'Fixture Owner',
        'ACME Camera 3.2.1',
      ]) {
        expect(
          _containsAscii(processed.bytes, secret),
          isFalse,
          reason: '"$secret" is still present in the stored file',
        );
      }
    });
  });

  group('capture time', () {
    test('is derived from EXIF DateTimeOriginal in UTC', () {
      final processed = processPhotoBytes(jpegWithSensitiveExif(), now: now);

      expect(processed.capturedAtFromExif, isTrue);
      expect(processed.capturedAt, fixtureExifNaiveCaptureTime.toUtc());
      expect(processed.capturedAt.isUtc, isTrue);
    });

    test('honours OffsetTimeOriginal when the camera recorded one', () {
      final processed = processPhotoBytes(
        jpegWithSensitiveExif(offsetTimeOriginal: '+02:00'),
        now: now,
      );

      expect(processed.capturedAtFromExif, isTrue);
      expect(processed.capturedAt, DateTime.utc(2026, 3, 4, 7, 15, 0));
    });

    test('falls back to the injected clock when EXIF has no timestamp', () {
      final processed = processPhotoBytes(jpegWithoutExif(), now: now);

      expect(processed.capturedAtFromExif, isFalse);
      expect(processed.capturedAt, now);
    });
  });

  group('resize and re-encode', () {
    test('long edge is capped at 1600 px', () {
      final processed = processPhotoBytes(
        jpegWithSensitiveExif(width: 2400, height: 1600),
        now: now,
      );

      expect(math.max(processed.width, processed.height), photoLongEdgePx);
      expect(processed.width, greaterThan(processed.height),
          reason: 'landscape must stay landscape');
    });

    test('small images are not upscaled', () {
      final processed = processPhotoBytes(
        jpegWithoutExif(width: 800, height: 600),
        now: now,
      );

      expect(processed.width, 800);
      expect(processed.height, 600);
    });

    test('orientation is baked into the pixels', () {
      // Orientation 6 means "rotate 90° clockwise to display upright", so a
      // landscape source is really a portrait photo.
      final processed = processPhotoBytes(
        jpegWithSensitiveExif(width: 2400, height: 1600, orientation: 6),
        now: now,
      );

      expect(processed.height, photoLongEdgePx);
      expect(processed.width, lessThan(processed.height));
      expect(readTag(processed.bytes, 'image', 'Orientation'), isNull);
    });

    test('recompression keeps a receipt well under the 250 KB target', () {
      final processed = processPhotoBytes(
        jpegWithSensitiveExif(width: 4000, height: 3000),
        now: now,
      );

      expect(processed.byteSize, lessThan(250 * 1024));
      expect(processed.byteSize, processed.bytes.length);
    });
  });

  group('hashing', () {
    test('sha256 is 64 hex characters and stable for identical input', () {
      final input = jpegWithSensitiveExif();

      final first = processPhotoBytes(input, now: now);
      final second = processPhotoBytes(input, now: now);

      expect(first.sha256Hex, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(first.sha256Hex, second.sha256Hex);
    });
  });

  group('bad input', () {
    test('rejects undecodable bytes', () {
      expect(
        () => processPhotoBytes(notAnImage(), now: now),
        throwsA(isA<PhotoProcessingException>()),
      );
    });

    test('rejects empty bytes', () {
      expect(
        () => processPhotoBytes(Uint8List(0), now: now),
        throwsA(isA<PhotoProcessingException>()),
      );
    });
  });
}

bool _containsAscii(Uint8List haystack, String needle) {
  final pattern = needle.codeUnits;
  if (pattern.isEmpty || pattern.length > haystack.length) return false;
  for (var i = 0; i <= haystack.length - pattern.length; i++) {
    var matched = true;
    for (var j = 0; j < pattern.length; j++) {
      if (haystack[i + j] != pattern[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}
