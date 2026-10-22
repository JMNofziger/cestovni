import 'package:cestovni/db/app_database.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/sync/dead_letter_summary.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';

void main() {
  test('retry clears the mark and discard keeps the local row', () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    final id = await db.into(db.outbox).insert(
          OutboxCompanion.insert(
            mutationId: '11111111-1111-4111-8111-111111111111',
            table_: 'fill_ups',
            op: 'insert',
            rowId: '22222222-2222-4222-8222-222222222222',
            payloadJson: const Value(
              '{"filled_at":"2026-04-03T08:00:00.000Z","id":"22222222-2222-4222-8222-222222222222"}',
            ),
            enqueuedAt: '2026-10-20T12:00:00.000Z',
          ),
        );
    await outbox.markDeadLetter(id, message: 'constraint_violation');
    final row = (await outbox.deadLetterRows()).single;
    expect(row.attempts, 1);
    expect(
      deadLetterSummary(row),
      "Fill-up on April 3 couldn't be backed up — server rejected it",
    );

    await outbox.retryDeadLetter(id);
    expect(await outbox.deadLetterCount(), 0);
    final retried = await (db.select(db.outbox)..where((o) => o.id.equals(id)))
        .getSingle();
    expect(retried.attempts, 0);
    expect(retried.lastError, isNull);
    expect(retried.mutationId, '11111111-1111-4111-8111-111111111111');

    await outbox.markDeadLetter(id, message: 'still bad');
    await outbox.discardDeadLetter(id);
    expect(await db.select(db.outbox).get(), isEmpty);
    final marks = await db.select(db.backupMarks).get();
    expect(marks.single.rowId, '22222222-2222-4222-8222-222222222222');
    expect(marks.single.markedTable, 'fill_ups');
  });
}
