import 'package:cestovni/app/app.dart';
import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests for the M1 shell (CES-56): four target tabs, vehicle
/// selector, theme toggle, and Settings reachable via the gear icon.
///
/// Each `testWidgets` ends with [_drainAndClose] to unmount the app,
/// drain Drift's stream-cleanup timers, and close the in-memory db.
/// Without this the test framework's `!timersPending` invariant fails
/// because Drift schedules zero-duration cleanup timers when stream
/// subscriptions are cancelled.
void main() {
  setUpAll(() {
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  testWidgets('shell renders 4 target tabs and switches between them',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(CestovniApp(db: db));
    await tester.pump();

    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('METRICS'), findsOneWidget);
    expect(find.text('MAINT.'), findsOneWidget);
    expect(find.text('Cestovni'), findsOneWidget);
    expect(find.text('Log a fuel-up'), findsOneWidget);

    await tester.tap(find.text('HISTORY'));
    await tester.pump();
    expect(find.text('History'), findsWidgets);

    await tester.tap(find.text('METRICS'));
    await tester.pump();
    expect(find.text('Metrics'), findsWidgets);

    await tester.tap(find.text('MAINT.'));
    await tester.pump();
    expect(find.text('Maintenance'), findsWidgets);

    await _drainAndClose(tester, db);
  });

  testWidgets('settings is reachable from header gear icon, not bottom tab',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(CestovniApp(db: db));
    await tester.pump();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Settings'),
        findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Distance unit'), findsOneWidget);

    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0001_init'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  testWidgets('active vehicle seeds from first live vehicle', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    await db.into(db.vehicles).insert(VehiclesCompanion.insert(
          id: '11111111-1111-4111-8111-111111111111',
          name: 'Daily Driver',
          fuelType: 'gasoline',
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          mutationId: '22222222-2222-4222-8222-222222222222',
        ));

    await tester.pumpWidget(CestovniApp(db: db));
    await tester.pump();
    await tester.pump();

    expect(find.text('DAILY DRIVER'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  testWidgets('shows NO VEHICLE chip when there are no live vehicles',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    await tester.pumpWidget(CestovniApp(db: db));
    await tester.pump();
    await tester.pump();

    expect(find.text('NO VEHICLE'), findsOneWidget);

    await _drainAndClose(tester, db);
  });

  test('ActiveVehicle notifies on change', () {
    final av = ActiveVehicle();
    var calls = 0;
    av.addListener(() => calls++);
    av.setVehicleId('a');
    av.setVehicleId('a');
    av.setVehicleId('b');
    expect(calls, 2);
    av.dispose();
  });
}

/// Tear-down helper: unmount the widget tree to cancel Drift stream
/// subscriptions, pump once to let the resulting zero-duration
/// cleanup timer fire, then close the db.
Future<void> _drainAndClose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}
