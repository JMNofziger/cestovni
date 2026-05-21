import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/history_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => CestovniTypography.useGoogleFonts = false);
  tearDownAll(() => CestovniTypography.useGoogleFonts = true);

  testWidgets('shows no-vehicle empty state', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(_host(db, null));
    await tester.pump();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('shows empty fill-ups hint when vehicle has none',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    expect(find.text('No fill-ups yet'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('lists fill-ups for active vehicle', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    final repo = FillUpsRepository(db);

    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 4, 18, 10),
      odometerM: 51460000,
      volumeUL: 13100000,
      totalPriceCents: 4520,
      currencyCode: 'EUR',
      isFull: true,
    ));
    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 3, 24, 10),
      odometerM: 50822000,
      volumeUL: 13300000,
      totalPriceCents: 4722,
      currencyCode: 'EUR',
      isFull: true,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    expect(find.text('€45.20'), findsOneWidget);
    expect(find.text('€47.22'), findsOneWidget);
    expect(find.textContaining('FUEL'), findsWidgets);

    await _drain(tester, db);
  });

  testWidgets('soft-delete removes row from list', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    final repo = FillUpsRepository(db);

    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 4, 18, 10),
      odometerM: 51460000,
      volumeUL: 13100000,
      totalPriceCents: 4520,
      currencyCode: 'EUR',
      isFull: true,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    expect(find.text('€45.20'), findsOneWidget);

    await tester.tap(find.text('€45.20'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fuel-up details'), findsOneWidget);

    await tester.tap(find.text('Delete entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('€45.20'), findsNothing);
    expect(find.text('No fill-ups yet'), findsOneWidget);

    final all = await repo.listForVehicle(vehicleId);
    expect(all, isEmpty);

    await _drain(tester, db);
  });

  testWidgets('detail sheet shows all fields', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    final repo = FillUpsRepository(db);

    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.utc(2026, 4, 18, 10, 15),
      odometerM: 51460000,
      volumeUL: 13100000,
      totalPriceCents: 4520,
      currencyCode: 'EUR',
      isFull: false,
      missedBefore: true,
      notes: 'Test note',
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('€45.20'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fuel-up details'), findsOneWidget);
    expect(find.text('PARTIAL'), findsOneWidget);
    expect(find.text('Yes'), findsWidgets);
    expect(find.text('Test note'), findsOneWidget);
    expect(find.text('MISSED BEFORE'), findsOneWidget);

    await _drain(tester, db);
  });
}

/// Unmount → pump to clear Drift's zero-duration cleanup timer → close.
Future<void> _drain(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
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
        body: HistoryPage(db: db, onOpenSettings: () {}),
      ),
    ),
  );
}
