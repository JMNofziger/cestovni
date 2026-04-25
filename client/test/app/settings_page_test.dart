import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/settings_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
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
