import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/settings_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the CES-39 phase 2 vehicle CRUD section embedded
/// in [SettingsPage]. Exercises the empty state, add-vehicle flow,
/// edit flow, and delete-with-confirm. We don't mount the full shell
/// here — `shell_smoke_test.dart` already covers that — so the harness
/// is just a `MaterialApp` + `ActiveVehicleScope`.
///
/// **Note:** Drift's `watch()` streams emit asynchronously and don't
/// quiesce, so we use `tester.pump()` twice (matching
/// `shell_smoke_test.dart`) instead of `pumpAndSettle()`. Each test
/// also drains the widget tree before closing the database to release
/// the stream subscription.
void main() {
  setUpAll(() {
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  testWidgets('shows empty-state copy when no vehicles exist', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(_host(SettingsPage(db: db)));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No vehicles yet. Add one to start logging fill-ups.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Add vehicle'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  testWidgets('Add vehicle button pushes the form and writes a new row',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(_host(SettingsPage(db: db)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Add vehicle'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Daily',
    );
    await tester.tap(find.text('ADD'));
    // Pump enough frames for the form to pop and the StreamBuilder
    // to receive the new row; we can't pumpAndSettle (Drift streams).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final live = await VehiclesRepository(db).liveOnce();
    expect(live.single.name, 'Daily',
        reason: 'row written to db is the source of truth');

    await _drainAndClose(tester, db);
  });

  testWidgets('row tap opens the edit form', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    await VehiclesRepository(db).create(
      const VehicleDraft(name: 'Octavia', fuelType: VehicleFuelType.gasoline),
    );

    await tester.pumpWidget(_host(SettingsPage(db: db)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Octavia'));
    await tester.pumpAndSettle();
    expect(find.text('Edit vehicle'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  testWidgets('delete asks for confirmation and respects Cancel',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final repo = VehiclesRepository(db);
    await repo.create(
      const VehicleDraft(name: 'Keeper', fuelType: VehicleFuelType.gasoline),
    );

    await tester.pumpWidget(_host(SettingsPage(db: db)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Keeper?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect((await repo.liveOnce()).length, 1,
        reason: 'Cancel must not soft-delete the row');
    expect(find.text('Keeper'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  testWidgets('confirmed delete soft-deletes and clears active id',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final repo = VehiclesRepository(db);
    final id = await repo.create(
      const VehicleDraft(
        name: 'Doomed',
        fuelType: VehicleFuelType.gasoline,
      ),
    );

    final active = ActiveVehicle(initialId: id);
    await tester.pumpWidget(_host(
      SettingsPage(db: db),
      active: active,
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump();

    expect((await repo.liveOnce()), isEmpty);
    expect(active.vehicleId, isNull,
        reason: 'deleting the active vehicle must clear ActiveVehicle');

    await _drainAndClose(tester, db);
  });

  group('CES-57 Preferences section', () {
    testWidgets('distance unit tile opens a picker and persists the choice',
        (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Kilometers (km)'), findsOneWidget);

      await tester.tap(find.text('Kilometers (km)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Miles (mi)'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.preferredDistanceUnit, 'mi');

      await _drainAndClose(tester, db);
    });

    testWidgets('volume unit tile opens a picker and persists the choice',
        (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Liters (L)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallons (gal)'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.preferredVolumeUnit, 'gal');

      await _drainAndClose(tester, db);
    });

    testWidgets('currency tile opens a dialog and persists a valid code',
        (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'czk');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.currencyCode, 'CZK', reason: 'normalized to uppercase');

      await _drainAndClose(tester, db);
    });

    testWidgets('currency dialog rejects an invalid code', (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'X');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a 3-letter ISO-4217 code (e.g. EUR).'),
        findsOneWidget,
      );
      final row = await settings.getOrBootstrap();
      expect(row.currencyCode, 'EUR', reason: 'invalid input rejected');

      // Dismiss the still-open dialog before tearing down — leaving it
      // mounted across the root-widget swap in `_drainAndClose` can
      // bleed pending focus/scheduler callbacks into the next test.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await _drainAndClose(tester, db);
    });

    testWidgets('timezone tile opens a dialog and persists a new value',
        (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('UTC'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Europe/Prague');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.timezone, 'Europe/Prague');

      await _drainAndClose(tester, db);
    });

    testWidgets(
        'default vehicle tile picks a live vehicle and persists its id',
        (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      await settings.getOrBootstrap();
      final vehicleId = await VehiclesRepository(db).create(
        const VehicleDraft(name: 'Octavia', fuelType: VehicleFuelType.gasoline),
      );

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('None — first vehicle wins'), findsOneWidget);

      await tester.tap(find.text('Default vehicle'));
      await tester.pumpAndSettle();
      // "Octavia" also appears in the Vehicles CRUD section above the
      // Preferences section; the bottom-sheet copy is the last match.
      await tester.tap(find.text('Octavia').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.defaultVehicleId, vehicleId);
      expect(find.text('Octavia'), findsWidgets);

      await _drainAndClose(tester, db);
    });

    testWidgets('default vehicle tile clears back to None', (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final settings = SettingsRepository(db);
      final vehicleId = await VehiclesRepository(db).create(
        const VehicleDraft(name: 'Octavia', fuelType: VehicleFuelType.gasoline),
      );
      await settings.update(defaultVehicleId: vehicleId);

      await tester.pumpWidget(_host(SettingsPage(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Octavia'), findsWidgets);

      await tester.tap(find.text('Default vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None — first vehicle wins'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final row = await settings.getOrBootstrap();
      expect(row.defaultVehicleId, isNull);

      await _drainAndClose(tester, db);
    });
  });
}

Widget _host(Widget child, {ActiveVehicle? active}) {
  final notifier = active ?? ActiveVehicle();
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: notifier,
      child: child,
    ),
  );
}

/// See `shell_smoke_test.dart` for the rationale: unmount the widget
/// tree to cancel Drift stream subscriptions, pump once to let the
/// resulting zero-duration cleanup timer fire, then close the db.
Future<void> _drainAndClose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}
