import 'package:drift/drift.dart';

/// Protocol columns carried by every **backed-up** table, per
/// docs/specs/adr/002-backup-sync-layer.md and docs/specs/data-model.md
/// (§ "Protocol columns").
///
/// On the client these columns are hydrated after a successful
/// `POST /mutations` (see sync-protocol.md). v1 code never fabricates
/// `row_version`, `user_id`, or `updated_at`; they exist here so the
/// client can persist the server's response.
mixin ProtocolColumns on Table {
  /// Client-generated UUIDv4 at creation; primary key.
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Server-assigned. Nullable on-device until the first successful
  /// server hydrate so rows inserted while offline still satisfy
  /// NOT NULL once the outbox drains.
  TextColumn get userId =>
      text().nullable().named('user_id').withLength(min: 36, max: 36)();

  /// Server-assigned from `cestovni_row_version_seq`. Nullable on-device
  /// until first hydrate (ADR 002: "never written by the client").
  IntColumn get rowVersion => integer().nullable().named('row_version')();

  /// Local/server wall-clock for human readability only (ISO-8601 UTC).
  TextColumn get updatedAt => text().named('updated_at')();

  /// Soft-delete marker; NULL when live.
  TextColumn get deletedAt => text().nullable().named('deleted_at')();

  /// Last idempotency key that touched the row; server dedupes retries.
  TextColumn get mutationId =>
      text().named('mutation_id').withLength(min: 36, max: 36)();
}
