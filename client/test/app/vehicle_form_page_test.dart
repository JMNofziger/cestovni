import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/vehicle_form_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the CES-39 phase 2 vehicle form. We mount the
/// page in a bare `MaterialApp` (no shell) so the tests stay focused
/// on form behavior; full settings-list flow is exercised in
/// `settings_page_test.dart`.
void main() {
  setUpAll(() {
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  testWidgets('blocks save when required fields are missing', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_host(VehicleFormPage(db: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);

    final repo = VehiclesRepository(db);
    expect(await repo.liveOnce(), isEmpty,
        reason: 'failed validation must not insert a row');
  });

  testWidgets('rejects out-of-range year', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_host(VehicleFormPage(db: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Year'), '1899');
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect(find.text('Year must be 1900-2100.'), findsOneWidget);
  });

  testWidgets('saves a new vehicle and pops with the new id', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    String? capturedId;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              capturedId =
                  await Navigator.of(ctx).push<String>(MaterialPageRoute(
                builder: (_) => VehicleFormPage(db: db),
              ));
            },
            child: const Text('Open form'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Octavia',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Year'),
      '2018',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tank capacity (L)'),
      '50',
    );
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect(capturedId, isNotNull);

    final live = await VehiclesRepository(db).liveOnce();
    expect(live.length, 1);
    expect(live.single.name, 'Octavia');
    expect(live.single.year, 2018);
    expect(live.single.tankCapacityUL, 50_000_000,
        reason: 'tank capacity stored as microlitres');
  });

  testWidgets('edit mode prefills + writes back changes', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = VehiclesRepository(db);
    final id = await repo.create(
      const VehicleDraft(
        name: 'Old name',
        fuelType: VehicleFuelType.gasoline,
        year: 2015,
      ),
    );
    final existing = await repo.findById(id);

    await tester.pumpWidget(_host(
      VehicleFormPage(db: db, existing: existing),
    ));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Name *'),
      findsOneWidget,
    );
    expect(find.text('Old name'), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'New name',
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final reread = await repo.findById(id);
    expect(reread!.name, 'New name');
    expect(reread.year, 2015, reason: 'untouched fields preserved');
  });
}

Widget _host(Widget child) {
  final activeVehicle = ActiveVehicle();
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: activeVehicle,
      child: child,
    ),
  );
}
