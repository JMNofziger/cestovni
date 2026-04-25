/// Write-time helpers for the `ProtocolColumns` mixin (see
/// `client/lib/db/tables/protocol.dart` and ADR 002).
///
/// On the client we generate `id`, `mutation_id`, and `updated_at`
/// locally for offline writes. `user_id` and `row_version` stay null
/// until the M3 outbox round-trips the row through the server. Soft
/// delete sets `deleted_at` and bumps `updated_at`; we never hard
/// delete from the UI.
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fresh UUIDv4 — used for `id` and `mutation_id` columns.
String newUuid() => _uuid.v4();

/// Current wall-clock as ISO-8601 UTC for `updated_at` / `deleted_at`
/// / `filled_at` etc. Tests inject deterministic timestamps via the
/// repository constructors.
String nowIsoUtc() => DateTime.now().toUtc().toIso8601String();
