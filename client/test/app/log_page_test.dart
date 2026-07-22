import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/log_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/drafts_repository.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => CestovniTypography.useGoogleFonts = false);
  tearDownAll(() => CestovniTypography.useGoogleFonts = true);

  testWidgets('shows no-vehicle empty state when vehicleId is null',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(_host(db, null));
    await tester.pump();

    expect(find.text('Log a Fuel-Up'), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('GO TO SETTINGS'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('blocks save when required fields are empty', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    await _scrollToAndTap(tester, 'SAVE ENTRY');
    await tester.pump();

    expect(find.text('Required'), findsWidgets);

    final repo = FillUpsRepository(db);
    expect(await repo.listForVehicle(vehicleId), isEmpty,
        reason: 'empty form must not insert a row');

    await _drain(tester, db);
  });

  testWidgets('saves fill-up with valid data', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '50000');
    await tester.pump();
    await tester.enterText(textFields.at(1), '35.5');
    await tester.pump();
    await tester.enterText(textFields.at(2), '52.00');
    await tester.pump();

    await _scrollToAndTap(tester, 'SAVE ENTRY');
    await tester.pump();
    await tester.pump();

    final repo = FillUpsRepository(db);
    final rows = await repo.listForVehicle(vehicleId);
    expect(rows, hasLength(1));
    expect(rows.first.odometerM, 50000 * 1000);
    expect(rows.first.volumeUL, closeTo(35.5 * 1000000, 1));
    expect(rows.first.totalPriceCents, 5200);

    await _drain(tester, db);
  });

  testWidgets('draft persists and resumes on reload', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '12345');
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));

    final drafts = DraftsRepository(db);
    final draft = await drafts.openDraftForVehicle(vehicleId);
    expect(draft, isNotNull);
    expect(draft!.odometerM, 12345 * 1000);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('12345'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('odometer regression is blocked unless reset enabled',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    final repo = FillUpsRepository(db);
    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 5, 1),
      odometerM: 100000000,
      volumeUL: 40000000,
      totalPriceCents: 5000,
      currencyCode: 'EUR',
      isFull: true,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '50000');
    await tester.pump();
    await tester.enterText(textFields.at(1), '35');
    await tester.pump();
    await tester.enterText(textFields.at(2), '50.00');
    await tester.pump();

    await _scrollToAndTap(tester, 'SAVE ENTRY');
    await tester.pump();

    expect(find.textContaining('Must be higher'), findsOneWidget);

    final rows = await repo.listForVehicle(vehicleId);
    expect(rows, hasLength(1), reason: 'regression must be blocked');

    await _drain(tester, db);
  });

  testWidgets('labels and save conversion follow settings prefs (CES-65)',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    await SettingsRepository(db).update(
      preferredDistanceUnit: 'mi',
      preferredVolumeUnit: 'gal',
      currencyCode: 'USD',
    );

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    expect(find.text('ODOMETER (MI)'), findsOneWidget);
    expect(find.text('VOLUME (GAL)'), findsOneWidget);
    expect(find.text('TOTAL (\$)'), findsOneWidget);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '100');
    await tester.pump();
    await tester.enterText(textFields.at(1), '4');
    await tester.pump();
    await tester.enterText(textFields.at(2), '30.00');
    await tester.pump();

    await _scrollToAndTap(tester, 'SAVE ENTRY');
    await tester.pump();
    await tester.pump();

    final repo = FillUpsRepository(db);
    final rows = await repo.listForVehicle(vehicleId);
    expect(rows, hasLength(1));
    // 100 mi = 160 934.4 m → banker's → 160 934 m.
    expect(rows.first.odometerM, 160934);
    // 4 US gal = 4 × 3 785 411 784 µL.
    expect(rows.first.volumeUL, 15141647136);
    expect(rows.first.totalPriceCents, 3000);
    expect(rows.first.currencyCode, 'USD');

    await _drain(tester, db);
  });

  testWidgets('first fill-up cannot set odometer reset', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '50000');
    await tester.pump();
    await tester.enterText(textFields.at(1), '35');
    await tester.pump();
    await tester.enterText(textFields.at(2), '50.00');
    await tester.pump();

    // Scroll and open advanced
    await tester.ensureVisible(find.text('ADVANCED'));
    await tester.pump();
    await tester.tap(find.text('ADVANCED'));
    await tester.pump();

    // Enable reset switch
    await tester.ensureVisible(find.text('ODOMETER RESET'));
    await tester.pump();
    final switches = find.byType(Switch);
    // Switches: PARTIAL FILL, MISSED BEFORE, ODOMETER RESET
    await tester.tap(switches.at(2));
    await tester.pump();

    await _scrollToAndTap(tester, 'SAVE ENTRY');
    await tester.pump();

    expect(find.textContaining('Cannot reset'), findsOneWidget);

    final repo = FillUpsRepository(db);
    expect(await repo.listForVehicle(vehicleId), isEmpty);

    await _drain(tester, db);
  });
}

/// Unmount → pump to clear Drift's zero-duration cleanup timer → close.
/// LogPage holds a live settings stream (CES-65), so closing the db
/// while the page is mounted would hang the test.
Future<void> _drain(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}

Future<void> _scrollToAndTap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<String> _seedVehicle(AppDatabase db) async {
  final repo = VehiclesRepository(db);
  return repo.create(const VehicleDraft(
    name: 'Test Car',
    fuelType: VehicleFuelType.gasoline,
  ));
}

Widget _host(AppDatabase db, String? vehicleId) {
  final activeVehicle = ActiveVehicle(initialId: vehicleId);
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: activeVehicle,
      child: Scaffold(
        body: LogPage(db: db, onOpenSettings: () {}),
      ),
    ),
  );
}
