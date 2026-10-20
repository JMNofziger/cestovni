import 'package:cestovni/app/active_vehicle.dart';
import 'package:cestovni/app/pages/settings_page.dart';
import 'package:cestovni/app/theme/cestovni_typography.dart';
import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    CestovniTypography.useGoogleFonts = false;
  });
  tearDownAll(() {
    CestovniTypography.useGoogleFonts = true;
  });

  testWidgets('Backup lists a dead-letter row and its actions', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final outbox = OutboxRepository(db);
    final id = await db.into(db.outbox).insert(
          OutboxCompanion.insert(
            mutationId: '11111111-1111-4111-8111-111111111111',
            table_: 'fill_ups',
            op: 'insert',
            rowId: '22222222-2222-4222-8222-222222222222',
            payloadJson: const Value(
              '{"filled_at":"2026-04-03T08:00:00.000Z"}',
            ),
            enqueuedAt: '2026-10-20T12:00:00.000Z',
          ),
        );
    await outbox.markDeadLetter(id, message: 'rejected by policy');

    await tester.pumpWidget(_host(SettingsPage(db: db)));
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Restore from backup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('1 change was not backed up'), findsOneWidget);
    expect(
      find.text("Fill-up on April 3 couldn't be backed up — server rejected it"),
      findsWidgets,
    );

    final details = find.byKey(ValueKey('dead-letter-details-$id'));
    await tester.ensureVisible(details);
    await tester.pump();
    await tester.tap(details);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('dead-letter:'), findsOneWidget);
    expect(find.textContaining('rejected by policy'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump();

    final retry = find.byKey(ValueKey('dead-letter-retry-$id'));
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();
    final retried = await (db.select(db.outbox)..where((o) => o.id.equals(id)))
        .getSingle();
    expect(retried.attempts, 0);
    expect(retried.lastError, isNull);

    await _drainAndClose(tester, db);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: ActiveVehicleScope(
      notifier: ActiveVehicle(),
      child: child,
    ),
  );
}

Future<void> _drainAndClose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await db.close();
}
