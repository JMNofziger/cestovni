import 'package:cestovni/db/repositories/fill_ups_repository.dart';
import 'package:cestovni/db/repositories/outbox_repository.dart';
import 'package:cestovni/db/repositories/vehicles_repository.dart';
import 'package:cestovni/export/snapshot.dart';
import 'package:cestovni/export/user_key_hash.dart';
import 'package:cestovni/export/zip_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../db/_harness.dart';

void main() {
  test('manifest records three pending outbox mutations and a stable hash',
      () async {
    final db = openInMemoryDb();
    addTearDown(db.close);
    final vehicleId = await VehiclesRepository(db).create(
      const VehicleDraft(name: 'Daily', fuelType: VehicleFuelType.gasoline),
    );
    final fills = FillUpsRepository(db);
    for (var i = 0; i < 3; i++) {
      await fills.create(
        FillUpDraft(
          vehicleId: vehicleId,
          filledAt: DateTime.utc(2026, 8, 1, 10, i),
          odometerM: 1000000 * (i + 1),
          volumeUL: 40000000,
          totalPriceCents: 5000,
          currencyCode: 'EUR',
          isFull: true,
        ),
      );
    }

    final ids = await OutboxRepository(db).pendingMutationIds();
    expect(ids, hasLength(3));
    final expectedHash = outboxPendingHash(ids);

    final snapshot = await takeExportSnapshot(db);
    expect(snapshot.pendingMutationIds, unorderedEquals(ids));
    expect(outboxPendingHash(snapshot.pendingMutationIds), expectedHash);

    final mem = MemoryZipSink();
    writeSnapshotToSink(
      sink: mem,
      snapshot: snapshot,
      appVersion: '0.0.1',
      exportedAt: DateTime.utc(2026, 8, 16, 12),
    );
    expect(mem.utf8Of('manifest.json'), contains('"outbox_pending_count": 3'));
    expect(mem.utf8Of('manifest.json'), contains(expectedHash!));
    expect(
      outboxPendingHash(ids),
      expectedHash,
      reason: 'hash is stable for a stable mutation_id set',
    );
  });

  test('empty outbox yields a null pending hash', () {
    expect(outboxPendingHash(const []), isNull);
  });
}
