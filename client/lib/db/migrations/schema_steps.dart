import 'package:drift/drift.dart';

import 'migration_runner.dart';

/// Ordered list of schema migration steps. Numbers align with the server
/// migration filenames under `db/migrations/NNNN_*.sql` per
/// docs/specs/data-model.md §"Migration alignment (client ↔ server)".
///
/// v1 ships only `0001_init`. Subsequent steps (e.g. `0002_add_…`) are
/// appended in later releases.
List<MigrationStep> schemaSteps(Iterable<TableInfo> allTables) {
  final tablesInOrder = allTables.toList(growable: false);
  return [
    MigrationStep(
      from: 0,
      to: 1,
      name: '0001_init',
      up: (m) async {
        for (final t in tablesInOrder) {
          await m.createTable(t);
        }
      },
      // Drift is forward-only in v1. `down` is wired so M5 rollback
      // tooling (CES-47) has a concrete hook to drive from a
      // "hard reset + restore" Settings flow (data-model.md §"Client
      // schema migration rollback"). Dropping in reverse order
      // satisfies the FK constraints.
      down: (m) async {
        for (final t in tablesInOrder.reversed) {
          await m.deleteTable(t.actualTableName);
        }
      },
    ),
  ];
}
