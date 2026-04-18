import 'package:cestovni/app/app.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test for the M0-01 shell: the three tabs render and are
/// switchable. Satisfies the CES-36 acceptance "navigable shell" in a
/// way that runs headless in CI.
void main() {
  testWidgets('shell has Home / Settings / Debug and is switchable',
      (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(CestovniApp(db: db));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);
    // AppBar starts on "Cestovni" (home).
    expect(find.widgetWithText(AppBar, 'Cestovni'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Distance unit'), findsOneWidget);

    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Debug'), findsOneWidget);
    expect(find.textContaining('0001_init'), findsOneWidget);
  });
}
