/// Log tab receipt-photo UI (CES-40).
///
/// Spec: `docs/specs/photo-pipeline.md` §"UX rules". The picker is faked —
/// the CI VM has no camera, no photo library and no Android SDK.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/log_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/photo_refs_repository.dart';
import 'package:cestovni/photos/photo_picker.dart';
import 'package:cestovni/photos/photo_service.dart';
import 'package:cestovni/photos/photo_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../photos/_fixtures.dart';

void main() {
  setUpAll(() => CestovniTypography.useGoogleFonts = false);
  tearDownAll(() => CestovniTypography.useGoogleFonts = true);

  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('cestovni-log-photos-');
    PhotoService.resetSweepThrottle();
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    PhotoService.resetSweepThrottle();
  });

  PhotoService photoServiceFor(AppDatabase db) => PhotoService(
        refs: PhotoRefsRepository(db),
        store:
            PhotoStore.inDirectory(Directory(p.join(sandbox.path, 'photos'))),
      );

  testWidgets('attach card starts empty and offers both sources',
      (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photoServiceFor(db),
      picker: _FakePicker(),
    ));
    await _settle(tester);

    expect(find.text('RECEIPT PHOTO (OPT.)'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('No photo attached.'), findsOneWidget);
    expect(find.text('CAMERA'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.textContaining('never backed up, never exported'),
        findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('attaching from the camera stores a stripped photo on the draft',
      (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);
    final photos = photoServiceFor(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photos,
      picker: _FakePicker(bytes: _smallJpegWithGps()),
    ));
    await _settle(tester);

    await _tapWithIo(tester, 'CAMERA');
    await _settle(tester);

    expect(_thumbnails(), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('No photo attached.'), findsNothing);

    final draft = await DraftsRepository(db).openDraftForVehicle(vehicleId);
    expect(draft, isNotNull,
        reason: 'attaching must create the draft row the photo points at');
    final rows = await PhotoRefsRepository(db).listForDraft(draft!.id);
    expect(rows, hasLength(1));

    final file = File(p.join(sandbox.path, 'photos', '${rows.first.id}.jpg'));
    expect(file.existsSync(), isTrue);
    expect(readTag(file.readAsBytesSync(), 'gps', 'GPSLatitude'), isNull);

    await _drain(tester, db);
  });

  testWidgets('the fifth photo disables both sources', (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);
    final photos = photoServiceFor(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photos,
      picker: _FakePicker(bytes: _smallJpeg()),
    ));
    await _settle(tester);

    for (var i = 0; i < maxPhotosPerDraft; i++) {
      await _tapWithIo(tester, 'CAMERA');
      await _settle(tester);
    }

    expect(find.text('5 / 5'), findsOneWidget);
    expect(_thumbnails(), findsNWidgets(maxPhotosPerDraft));
    expect(find.textContaining('Limit of 5 photos reached'), findsOneWidget);

    for (final label in const ['CAMERA', 'LIBRARY']) {
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull, reason: '$label must be disabled');
    }

    await _drain(tester, db);
  });

  testWidgets('preview dialog deletes the photo and its file', (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);
    final photos = photoServiceFor(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photos,
      picker: _FakePicker(bytes: _smallJpeg()),
    ));
    await _settle(tester);
    await _tapWithIo(tester, 'LIBRARY');
    await _settle(tester);

    final draft = await DraftsRepository(db).openDraftForVehicle(vehicleId);
    final row = (await PhotoRefsRepository(db).listForDraft(draft!.id)).single;
    final file = File(p.join(sandbox.path, 'photos', '${row.id}.jpg'));
    expect(file.existsSync(), isTrue);

    await tester.tap(_thumbnails());
    await _settle(tester);
    expect(find.text('DELETE PHOTO'), findsOneWidget);

    await _tapWithIo(tester, 'DELETE PHOTO');
    await _settle(tester);

    expect(_thumbnails(), findsNothing);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(file.existsSync(), isFalse);
    expect(await PhotoRefsRepository(db).listForDraft(draft.id), isEmpty);

    await _drain(tester, db);
  });

  testWidgets('denied camera access hides attach but still saves the fill-up',
      (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photoServiceFor(db),
      picker: _FakePicker(denied: true),
    ));
    await _settle(tester);

    await _tapWithIo(tester, 'CAMERA');
    await _settle(tester);

    expect(find.text('CAMERA'), findsNothing);
    expect(find.text('LIBRARY'), findsNothing);
    expect(find.textContaining('You can still save the fill-up'),
        findsOneWidget);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '50000');
    await tester.pump();
    await tester.enterText(textFields.at(1), '35.5');
    await tester.pump();
    await tester.enterText(textFields.at(2), '52.00');
    await tester.pump();

    await _tap(tester, 'SAVE ENTRY');
    await _settle(tester);

    final rows = await FillUpsRepository(db).listForVehicle(vehicleId);
    expect(rows, hasLength(1),
        reason: 'a refused camera prompt must never gate a fill-up');

    await _drain(tester, db);
  });

  testWidgets('saving the entry shortens the photo TTL and clears the strip',
      (tester) async {
    final db = _openDb();
    final vehicleId = await _seedVehicle(db);
    final photos = photoServiceFor(db);

    await tester.pumpWidget(_host(
      db: db,
      vehicleId: vehicleId,
      photos: photos,
      // No EXIF timestamp, so capture time is "now" and the capture TTL sits
      // 30 days out — the case where completion actually shortens it.
      picker: _FakePicker(bytes: _smallJpeg()),
    ));
    await _settle(tester);
    await _tapWithIo(tester, 'CAMERA');
    await _settle(tester);

    final draft = await DraftsRepository(db).openDraftForVehicle(vehicleId);
    final before = (await PhotoRefsRepository(db).listForDraft(draft!.id)).single;
    final beforeTtl = DateTime.parse(before.ttlExpiresAt);
    expect(beforeTtl.difference(DateTime.now().toUtc()).inDays,
        inInclusiveRange(29, 30));

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '50000');
    await tester.pump();
    await tester.enterText(textFields.at(1), '35.5');
    await tester.pump();
    await tester.enterText(textFields.at(2), '52.00');
    await tester.pump();

    await _tap(tester, 'SAVE ENTRY');
    await _settle(tester);

    expect(_thumbnails(), findsNothing);
    expect(find.text('0 / 5'), findsOneWidget);

    final after = await PhotoRefsRepository(db).findById(before.id);
    expect(after, isNotNull, reason: 'the photo survives until its TTL');
    final afterTtl = DateTime.parse(after!.ttlExpiresAt);
    expect(afterTtl.isBefore(beforeTtl), isTrue,
        reason: 'completing the entry must shorten the TTL');
    expect(afterTtl.difference(DateTime.now().toUtc()).inDays,
        inInclusiveRange(6, 7),
        reason: 'post-completion TTL is 7 days');

    await _drain(tester, db);
  });
}

// ══════════════════════════════════════════════════════════════════════
// Harness
// ══════════════════════════════════════════════════════════════════════

class _FakePicker implements PhotoPicker {
  _FakePicker({this.bytes, this.denied = false});

  final Uint8List? bytes;
  final bool denied;
  int calls = 0;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    calls++;
    if (denied) throw PhotoPermissionDeniedException(source);
    return bytes;
  }
}

Uint8List _smallJpeg() => jpegWithoutExif(width: 400, height: 300);

Uint8List _smallJpegWithGps() =>
    jpegWithSensitiveExif(width: 400, height: 300);

AppDatabase _openDb() => AppDatabase.withExecutor(NativeDatabase.memory());

Future<String> _seedVehicle(AppDatabase db) => VehiclesRepository(db).create(
      const VehicleDraft(name: 'Test Car', fuelType: VehicleFuelType.gasoline),
    );

Finder _thumbnails() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('photo-thumb-'),
    );

/// `pumpAndSettle` is avoided: unresolved `Image.file` futures keep the tree
/// dirty in a headless test, so frames are pumped explicitly instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Taps [label] for an action that touches the photo sandbox.
///
/// `dart:io` futures created inside `flutter_test`'s fake-async zone never
/// complete, no matter how much time is pumped afterwards, so the tap itself
/// has to be dispatched inside [WidgetTester.runAsync] — that is the only way
/// the attach / delete chain reaches the file system.
Future<void> _tapWithIo(WidgetTester tester, String label) async {
  final finder = await _reveal(tester, label);
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _settle(tester);
}

/// Taps [label] for an action that only touches the database.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(await _reveal(tester, label));
  await _settle(tester);
}

/// Scrolls [label] into view, ready to be tapped.
///
/// Frames are pumped *before* the scroll, not after: entering text focuses a
/// field, which scrolls itself into view over the following frames, and any
/// scrolling done ahead of that gets undone.
Future<Finder> _reveal(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await _settle(tester);
  await tester.ensureVisible(finder);
  await tester.pump();
  return finder;
}

/// Unmount → pump to clear Drift's cleanup timer → close.
Future<void> _drain(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}

Widget _host({
  required AppDatabase db,
  required String vehicleId,
  required PhotoService photos,
  required PhotoPicker picker,
}) {
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: ActiveVehicle(initialId: vehicleId),
      child: Scaffold(
        body: LogPage(
          db: db,
          onOpenSettings: () {},
          photoService: photos,
          photoPicker: picker,
        ),
      ),
    ),
  );
}
