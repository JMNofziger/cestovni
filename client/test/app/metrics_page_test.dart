import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/metrics_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/settings_repository.dart';
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

    expect(find.text('Metrics'), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('GO TO SETTINGS'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('shows empty copy when vehicle has no fill-ups',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);

    await tester.pumpWidget(_host(db, vehicleId));
    await _settle(tester);

    expect(find.text('No fill-ups yet'), findsOneWidget);
    // Range toggle stays visible so the layout doesn't dead-end.
    expect(find.text('ALL'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('happy path: lifetime card, tiles, and chart on ALL',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    await _seedFourFillUps(db, vehicleId);

    await tester.pumpWidget(_host(db, vehicleId));
    await _settle(tester);

    expect(find.text('LIFETIME COST'), findsOneWidget);
    expect(find.text('€257.00'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('1,800 km'), findsOneWidget);
    // 130 L over 1 800 km → 7.2 L/100km.
    expect(find.text('AVG L/100KM'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(find.text('FILL-UPS'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Cost over time'), findsOneWidget);
    expect(find.text('FIG.'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('NOT ENOUGH DATA'), findsNothing);

    await _drain(tester, db);
  });

  testWidgets('range switch to 30D updates visible aggregates',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    await _seedFourFillUps(db, vehicleId);

    await tester.pumpWidget(_host(db, vehicleId));
    await _settle(tester);

    expect(find.text('€257.00'), findsOneWidget);

    await tester.tap(find.text('30D'));
    await _settle(tester);

    // Last 30 days holds the two recent fill-ups (spend €127) and the
    // two segments closing inside the window (1 200 km, 85 L → 7.1).
    expect(find.text('30D COST'), findsOneWidget);
    expect(find.text('€127.00'), findsOneWidget);
    expect(find.text('1,200 km'), findsOneWidget);
    expect(find.text('7.1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('€257.00'), findsNothing);
    expect(find.text('NOT ENOUGH DATA'), findsNothing);

    await _drain(tester, db);
  });

  testWidgets('single in-range point shows layout-preserving placeholder',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    final repo = FillUpsRepository(db);
    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      odometerM: 50000000,
      volumeUL: 40000000,
      totalPriceCents: 6000,
      currencyCode: 'EUR',
      isFull: true,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await _settle(tester);

    expect(find.text('NOT ENOUGH DATA'), findsOneWidget);
    // Card + summary still render — layout preserved, no dead end.
    expect(find.text('Cost over time'), findsOneWidget);
    expect(find.text('€60.00'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('units and currency follow settings prefs', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await _seedVehicle(db);
    await SettingsRepository(db).update(
      preferredDistanceUnit: 'mi',
      preferredVolumeUnit: 'gal',
      currencyCode: 'USD',
    );
    final repo = FillUpsRepository(db);
    // Two full fill-ups 160 934 m (100 mi) apart on 4 US gal.
    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      odometerM: 50000000,
      volumeUL: 40000000,
      totalPriceCents: 6000,
      currencyCode: 'USD',
      isFull: true,
    ));
    await repo.create(FillUpDraft(
      vehicleId: vehicleId,
      filledAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      odometerM: 50160934,
      volumeUL: 15141647136,
      totalPriceCents: 4000,
      currencyCode: 'USD',
      isFull: true,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await _settle(tester);

    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('100 mi'), findsOneWidget);
    expect(find.text('VOL (GAL)'), findsOneWidget);
    expect(find.text('AVG MPG'), findsOneWidget);
    expect(find.text('25.0'), findsOneWidget);

    await _drain(tester, db);
  });
}

/// A few plain pumps — Drift streams emit asynchronously and the page
/// nests two StreamBuilders; avoid `pumpAndSettle` per repo test
/// conventions.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
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

/// Four full fill-ups: two older than 30 days, two recent.
///
/// Lifetime: 1 800 km, €257, 130 L across three segments → 7.2
/// L/100km. Last 30 days: fill-ups c + d (€127, 2 chart points);
/// segments (b→c] + (c→d] close inside the window → 1 200 km, 85 L
/// → 7.1 L/100km.
Future<void> _seedFourFillUps(AppDatabase db, String vehicleId) async {
  final repo = FillUpsRepository(db);
  final now = DateTime.now().toUtc();
  await repo.create(FillUpDraft(
    vehicleId: vehicleId,
    filledAt: now.subtract(const Duration(days: 40)),
    odometerM: 50000000,
    volumeUL: 40000000,
    totalPriceCents: 6000,
    currencyCode: 'EUR',
    isFull: true,
  ));
  await repo.create(FillUpDraft(
    vehicleId: vehicleId,
    filledAt: now.subtract(const Duration(days: 35)),
    odometerM: 50600000,
    volumeUL: 45000000,
    totalPriceCents: 7000,
    currencyCode: 'EUR',
    isFull: true,
  ));
  await repo.create(FillUpDraft(
    vehicleId: vehicleId,
    filledAt: now.subtract(const Duration(days: 10)),
    odometerM: 51200000,
    volumeUL: 42000000,
    totalPriceCents: 6500,
    currencyCode: 'EUR',
    isFull: true,
  ));
  await repo.create(FillUpDraft(
    vehicleId: vehicleId,
    filledAt: now.subtract(const Duration(days: 2)),
    odometerM: 51800000,
    volumeUL: 43000000,
    totalPriceCents: 6200,
    currencyCode: 'EUR',
    isFull: true,
  ));
}

Widget _host(AppDatabase db, String? vehicleId) {
  final activeVehicle = ActiveVehicle(initialId: vehicleId);
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: activeVehicle,
      child: Scaffold(
        body: MetricsPage(db: db, onOpenSettings: () {}),
      ),
    ),
  );
}
