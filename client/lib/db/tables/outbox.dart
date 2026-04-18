import 'package:drift/drift.dart';

/// Client-only `outbox` table from docs/specs/sync-protocol.md
/// (§ "Client outbox (local only)"). Never sent as-is to the server;
/// carries no protocol columns.
///
/// Retries reuse the same `mutation_id`; server dedupes and returns the
/// original `row_version` (ADR 002).
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mutationId =>
      text().named('mutation_id').withLength(min: 36, max: 36)();

  TextColumn get table_ => text().named('table').customConstraint(
        "NOT NULL CHECK (\"table\" IN "
        "('vehicles','fill_ups','maintenance_rules','maintenance_events','settings'))",
      )();

  TextColumn get op => text().customConstraint(
        "NOT NULL CHECK (op IN ('insert','update','soft_delete'))",
      )();

  TextColumn get rowId =>
      text().named('row_id').withLength(min: 36, max: 36)();

  TextColumn get payloadJson => text().nullable().named('payload_json')();

  TextColumn get enqueuedAt => text().named('enqueued_at')();

  IntColumn get attempts =>
      integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable().named('last_error')();
}
