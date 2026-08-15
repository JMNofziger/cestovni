/// Persistence, limits and cleanup for receipt photos.
///
/// Spec: `docs/specs/photo-pipeline.md` §Lifecycle, §"Soft limits",
/// §"Cleanup triggers" + §"Test expectations" items 2 and 3.
library;

import 'dart:io';

import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/photo_refs_repository.dart';
import 'package:cestovni/photos/photo_service.dart';
import 'package:cestovni/photos/photo_store.dart';
import 'package:cestovni/photos/photo_ttl.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '_db_helpers.dart';
import '_fixtures.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('cestovni-photos-test-');
    PhotoService.resetSweepThrottle();
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    PhotoService.resetSweepThrottle();
  });

  PhotoStore storeFor() =>
      PhotoStore.inDirectory(Directory(p.join(sandbox.path, 'photos')));

  PhotoService serviceFor(AppDatabase db, {DateTime Function()? clock}) =>
      PhotoService(
        refs: PhotoRefsRepository(db),
        store: storeFor(),
        clock: clock,
      );

  group('attach', () {
    test('writes a stripped file plus a row whose hash matches the file',
        () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final now = DateTime.utc(2026, 8, 15, 12);
      final photos = serviceFor(db, clock: () => now);

      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithSensitiveExif(),
      );

      expect(await attachment.file.exists(), isTrue);
      expect(p.basename(attachment.file.path), '${attachment.id}.jpg');

      final onDisk = await attachment.file.readAsBytes();
      expect(attachment.byteSize, onDisk.length);
      expect(attachment.row.sha256, sha256.convert(onDisk).toString());
      expect(readTag(onDisk, 'gps', 'GPSLatitude'), isNull);
    });

    test('stamps captured_at from EXIF and a 30 day TTL', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos =
          serviceFor(db, clock: () => DateTime.utc(2026, 8, 15, 12));

      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithSensitiveExif(),
      );

      expect(attachment.capturedAt, fixtureExifNaiveCaptureTime.toUtc());
      expect(
        attachment.ttlExpiresAt,
        fixtureExifNaiveCaptureTime.toUtc().add(photoCaptureTtl),
      );
    });

    test('caps a draft at five photos without leaving a stray file',
        () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);

      for (var i = 0; i < maxPhotosPerDraft; i++) {
        await photos.attachFromBytes(
          draftId: draftId,
          bytes: jpegWithoutExif(),
        );
      }

      await expectLater(
        photos.attachFromBytes(draftId: draftId, bytes: jpegWithoutExif()),
        throwsA(isA<PhotoLimitExceededException>()),
      );

      expect(await photos.countForDraft(draftId), maxPhotosPerDraft);
      expect(await storeFor().storedIds(), hasLength(maxPhotosPerDraft));
    });

    test('rejects undecodable bytes without touching the sandbox', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);

      await expectLater(
        photos.attachFromBytes(draftId: draftId, bytes: notAnImage()),
        throwsA(isA<Object>()),
      );

      expect(await photos.countForDraft(draftId), 0);
      expect(await storeFor().storedIds(), isEmpty);
    });
  });

  group('user deletes', () {
    test('delete removes the file and the row immediately', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);
      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithoutExif(),
      );

      expect(await photos.delete(attachment.id), isTrue);

      expect(await attachment.file.exists(), isFalse);
      expect(await photos.countForDraft(draftId), 0);
    });

    test('discarding a draft purges its photos first', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);
      final drafts = DraftsRepository(db);
      final first = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithoutExif(),
      );
      final second = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithoutExif(),
      );

      final discarded =
          await drafts.discard(draftId, purgePhotos: photos.purgeDraft);

      expect(discarded, isTrue);
      expect(await first.file.exists(), isFalse);
      expect(await second.file.exists(), isFalse);
      expect(await PhotoRefsRepository(db).listAll(), isEmpty);
    });
  });

  group('completion', () {
    test('shortens the TTL to seven days after completion', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);
      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithSensitiveExif(),
      );
      final completedAt = fixtureExifNaiveCaptureTime.toUtc().add(
            const Duration(days: 1),
          );

      final shortened =
          await photos.onDraftCompleted(draftId, completedAt: completedAt);

      expect(shortened, 1);
      final reread = await PhotoRefsRepository(db).findById(attachment.id);
      expect(
        DateTime.parse(reread!.ttlExpiresAt),
        completedAt.add(photoPostCompletionTtl),
      );
    });

    test('never extends a TTL that is already sooner', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);
      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithSensitiveExif(),
      );
      final captureExpiry =
          fixtureExifNaiveCaptureTime.toUtc().add(photoCaptureTtl);

      // Fill-up entered 29 days late: +7d would outlive the capture TTL.
      final shortened = await photos.onDraftCompleted(
        draftId,
        completedAt: fixtureExifNaiveCaptureTime.toUtc().add(
              const Duration(days: 29),
            ),
      );

      expect(shortened, 0);
      final reread = await PhotoRefsRepository(db).findById(attachment.id);
      expect(DateTime.parse(reread!.ttlExpiresAt), captureExpiry);
    });
  });

  group('cleanup sweep', () {
    test('purges expired photos and keeps the ones still in window',
        () async {
      final db = openDb();
      addTearDown(db.close);
      final now = DateTime.utc(2026, 8, 15, 12);
      var clock = now;
      final photos = serviceFor(db, clock: () => clock);

      // 29 days old — inside the 30 day capture window, must survive.
      clock = now.subtract(const Duration(days: 29));
      final fresh = await photos.attachFromBytes(
        draftId: (await seedDraft(db)).draftId,
        bytes: jpegWithoutExif(),
      );

      // 31 days old — past the capture TTL.
      clock = now.subtract(const Duration(days: 31));
      final stale = await photos.attachFromBytes(
        draftId: (await seedDraft(db)).draftId,
        bytes: jpegWithoutExif(),
      );

      // 10 days old but the fill-up completed 8 days ago, so the 7 day
      // post-completion TTL has already elapsed.
      clock = now.subtract(const Duration(days: 10));
      final completedDraftId = (await seedDraft(db)).draftId;
      final completed = await photos.attachFromBytes(
        draftId: completedDraftId,
        bytes: jpegWithoutExif(),
      );
      await photos.onDraftCompleted(
        completedDraftId,
        completedAt: now.subtract(const Duration(days: 8)),
      );

      clock = now;
      final result = await photos.sweep();

      expect(result.expiredPurged, 2);
      expect(result.orphanRowsDropped, 0);
      expect(await fresh.file.exists(), isTrue);
      expect(await stale.file.exists(), isFalse);
      expect(await completed.file.exists(), isFalse);

      final surviving = await PhotoRefsRepository(db).listAll();
      expect(surviving.map((r) => r.id), [fresh.id]);
    });

    test('drops an orphan row when the file vanished out of band', () async {
      final db = openDb();
      addTearDown(db.close);
      final draftId = (await seedDraft(db)).draftId;
      final photos = serviceFor(db);
      final attachment = await photos.attachFromBytes(
        draftId: draftId,
        bytes: jpegWithoutExif(),
      );

      await attachment.file.delete();
      final result = await photos.sweep();

      expect(result.orphanRowsDropped, 1);
      expect(await PhotoRefsRepository(db).listAll(), isEmpty);
    });

    test('deletes an orphan file that has no row', () async {
      final db = openDb();
      addTearDown(db.close);
      final photos = serviceFor(db);
      final store = storeFor();
      await store.write('9f1c3f0e-0000-4000-8000-000000000001',
          jpegWithoutExif());

      final result = await photos.sweep();

      expect(result.orphanFilesDeleted, 1);
      expect(await store.storedIds(), isEmpty);
    });

    test('is throttled to once per interval', () async {
      final db = openDb();
      addTearDown(db.close);
      final now = DateTime.utc(2026, 8, 15, 12);
      final photos = serviceFor(db, clock: () => now);

      expect(await photos.sweepThrottled(now: now), isNotNull);
      expect(await photos.sweepThrottled(now: now.add(const Duration(minutes: 30))),
          isNull);
      expect(
        await photos.sweepThrottled(now: now.add(const Duration(hours: 2))),
        isNotNull,
      );
    });

    test('records a sweep failure instead of breaking the caller', () async {
      final db = openDb();
      addTearDown(db.close);
      final photos = PhotoService(
        refs: PhotoRefsRepository(db),
        store: PhotoStore(
          resolveRoot: () async => throw const FileSystemException(
            'sandbox unavailable',
          ),
        ),
      );

      final result = await photos.sweepThrottled(
        now: DateTime.utc(2026, 8, 15, 12),
      );

      expect(result, isNull);
      expect(photos.lastSweepError, contains('sandbox unavailable'));
    });
  });
}

