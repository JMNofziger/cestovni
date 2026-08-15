/// The core privacy invariant: receipt photo bytes never leave the device.
///
/// Spec: `docs/specs/photo-pipeline.md` §Non-negotiables 1 and 2 +
/// `docs/specs/platform-compliance-v1.md` §receipt photos. Linear CES-40
/// acceptance: "photo bytes never appear in any outbox payload or export
/// ZIP".
library;

import 'dart:io';

import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/photo_refs_repository.dart';
import 'package:cestovni/photos/photo_export_guard.dart';
import 'package:cestovni/photos/photo_service.dart';
import 'package:cestovni/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '_db_helpers.dart';
import '_fixtures.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('cestovni-photos-outbox-');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('completing a fill-up with photos enqueues no photo bytes', () async {
    final db = openDb();
    addTearDown(db.close);
    final seeded = await seedDraft(db);
    final photos = PhotoService(
      refs: PhotoRefsRepository(db),
      store: PhotoStore.inDirectory(Directory(p.join(sandbox.path, 'photos'))),
      processor: processPhotoInProcess,
    );

    final first = await photos.attachFromBytes(
      draftId: seeded.draftId,
      bytes: jpegWithSensitiveExif(),
    );
    final second = await photos.attachFromBytes(
      draftId: seeded.draftId,
      bytes: jpegWithoutExif(),
    );

    await FillUpsRepository(db).create(FillUpDraft(
      vehicleId: seeded.vehicleId,
      filledAt: DateTime.utc(2026, 8, 15, 9),
      odometerM: 120000000,
      volumeUL: 42000000,
      totalPriceCents: 6100,
      currencyCode: 'EUR',
      isFull: true,
    ));
    await DraftsRepository(db).markCompleted(seeded.draftId);
    await photos.onDraftCompleted(seeded.draftId);

    final outboxRows = await db.select(db.outbox).get();

    expect(outboxRows, hasLength(1),
        reason: 'only the fill-up insert may be enqueued; attaching a photo '
            'must enqueue nothing');

    for (final row in outboxRows) {
      expect(row.table_, isNot('photo_refs'));
      final payload = row.payloadJson ?? '';
      expect(payload.toLowerCase(), isNot(contains('photo')));
      expect(payload, isNot(contains(first.row.sha256)));
      expect(payload, isNot(contains(second.row.sha256)));
      // Base64 of a JPEG always starts `/9j/`.
      expect(payload, isNot(contains('/9j/')));
    }
  });

  test('the outbox schema refuses a photo_refs mutation outright', () async {
    final db = openDb();
    addTearDown(db.close);

    await expectLater(
      db.customStatement(
        'INSERT INTO outbox (mutation_id, "table", op, row_id, enqueued_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          '11111111-1111-4111-8111-111111111111',
          'photo_refs',
          'insert',
          '22222222-2222-4222-8222-222222222222',
          DateTime.utc(2026, 8, 15).toIso8601String(),
        ],
      ),
      throwsA(isA<Object>()),
    );
  });

  test('export never lists the photo sandbox', () {
    final candidates = [
      'manifest.json',
      'README_export.txt',
      'fill_ups.csv',
      'photos/9f1c3f0e-0000-4000-8000-000000000001.jpg',
      p.join('photos', 'another.jpg'),
      'notes/photos-are-excluded.txt',
    ];

    final included = excludePhotoPaths(candidates);

    expect(included.any(isPhotoSandboxPath), isFalse);
    expect(included, contains('manifest.json'));
    expect(included, contains('notes/photos-are-excluded.txt'),
        reason: 'only the photos/ directory is excluded, not every path that '
            'happens to mention photos');
    expect(photosInExport, isFalse);
  });
}
