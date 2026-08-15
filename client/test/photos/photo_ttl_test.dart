/// TTL arithmetic for receipt photos.
///
/// Spec: `docs/specs/photo-pipeline.md` §Lifecycle — the shorter of 30 days
/// from capture or 7 days after the linked fill-up completes.
library;

import 'package:cestovni/photos/photo_ttl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 8, 1, 10, 0, 0);

  test('capture TTL is 30 days after capture', () {
    expect(captureTtlExpiry(capturedAt), DateTime.utc(2026, 8, 31, 10, 0, 0));
  });

  test('capture TTL normalises a local capture time to UTC', () {
    final local = DateTime(2026, 8, 1, 10, 0, 0);

    expect(captureTtlExpiry(local), local.toUtc().add(photoCaptureTtl));
  });

  group('completion TTL', () {
    test('shortens the window to 7 days after completion', () {
      final expiry = completionTtlExpiry(
        completedAt: DateTime.utc(2026, 8, 2),
        currentExpiry: captureTtlExpiry(capturedAt),
      );

      expect(expiry, DateTime.utc(2026, 8, 9));
    });

    test('never extends an expiry that is already sooner', () {
      // Fill-up entered 29 days after the photo was taken: 7 more days would
      // outlive the 30-day capture TTL, so the capture TTL wins.
      final captureExpiry = captureTtlExpiry(capturedAt);

      final expiry = completionTtlExpiry(
        completedAt: DateTime.utc(2026, 8, 30),
        currentExpiry: captureExpiry,
      );

      expect(expiry, captureExpiry);
    });
  });

  group('expiry check', () {
    final now = DateTime.utc(2026, 8, 15, 12, 0, 0);

    test('future expiry is not expired', () {
      expect(
        isPhotoExpired(ttlExpiresAt: now.add(const Duration(seconds: 1)), now: now),
        isFalse,
      );
    });

    test('past expiry is expired', () {
      expect(
        isPhotoExpired(
            ttlExpiresAt: now.subtract(const Duration(seconds: 1)), now: now),
        isTrue,
      );
    });

    test('boundary is inclusive so a row is never left one pass behind', () {
      expect(isPhotoExpired(ttlExpiresAt: now, now: now), isTrue);
    });
  });
}
