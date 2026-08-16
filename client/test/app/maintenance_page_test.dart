import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/maintenance_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/maintenance_events_repository.dart';
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

    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('GO TO SETTINGS'), findsOneWidget);

    await _drain(tester, db);
  });

  testWidgets('saves an oil change and lists it', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final vehicleId = await VehiclesRepository(db).create(const VehicleDraft(
      name: 'Test Car',
      fuelType: VehicleFuelType.gasoline,
    ));

    await tester.pumpWidget(_host(db, vehicleId));
    await tester.pump();
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '120000');
    await tester.enterText(fields.at(1), '89');
    await tester.enterText(fields.at(2), 'Bosch');

    await tester.scrollUntilVisible(
      find.text('SAVE ENTRY'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('SAVE ENTRY'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(5), '6');
    await tester.tap(find.text('SAVE ENTRY'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Maintenance saved'), findsOneWidget);
    expect(find.textContaining('Oil'), findsWidgets);

    final rows = await MaintenanceEventsRepository(db).listForVehicle(vehicleId);
    expect(rows, hasLength(1));
    expect(rows.first.category, 'oil');
    expect(rows.first.costCents, 8900);
    expect(rows.first.shop, 'Bosch');
    expect(rows.first.odometerM, 120000000); // 120000 km → meters
    expect(rows.first.ruleId, isNotNull);

    final rule = await MaintenanceEventsRepository(db)
        .findRuleByVehicleAndName(vehicleId, 'oil');
    expect(rule, isNotNull);
    expect(rule!.cadenceDays, 180);

    await _drain(tester, db);
  });
}

Future<void> _drain(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}

Widget _host(AppDatabase db, String? vehicleId) {
  final activeVehicle = ActiveVehicle(initialId: vehicleId);
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: activeVehicle,
      child: Scaffold(
        body: MaintenancePage(db: db, onOpenSettings: () {}),
      ),
    ),
  );
}
