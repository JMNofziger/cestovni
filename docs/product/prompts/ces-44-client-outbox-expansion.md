# Cursor execution prompt — CES-44 Client outbox expansion (all backed-up tables)

> **Status: NOT STARTED.**
> **Linear:** [CES-44](https://linear.app/personal-interests-llc/issue/CES-44) — Backlog.
> **Blocked by:** CES-43 (Server API + auth must merge first).
> **Blocks:** CES-45 (Restore + dead-letter UX).
> This is the third M3 ticket. Do not start CES-45 until this merges.

**Branch:** cut from **`main`** (after CES-43 merges)
**Spec (normative):** [`docs/specs/sync-protocol.md`](../../specs/sync-protocol.md) + [`docs/specs/adr/002-backup-sync-layer.md`](../../specs/adr/002-backup-sync-layer.md)
**Also read:** [`docs/specs/data-model.md`](../../specs/data-model.md) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-43** Server API + auth on `main` |
| M0–M2 | **Closed.** Client DB at schema v5. Export + import shipped. |
| M3 | **CES-42 done** (Postgres + RLS). **CES-43 done** (Server API + auth + contract tests). |
| Fill-up outbox | `client/lib/sync/` + `client/lib/db/repositories/outbox_repository.dart` — **gate slice on `main`**. Fill-ups `create`/`amend`/`softDelete` already enqueue to the outbox + flush via `OutboxFlushWorker`. |
| Vehicles outbox | **Not wired.** `VehiclesRepository` writes directly to local table with no outbox side-effect. Docstring says "M3 will layer the outbox-enqueue side-effect on top of these calls." |
| Settings outbox | **Not wired.** `SettingsRepository.update` writes in place; no outbox enqueue. |
| Maintenance outbox | **Not wired.** `MaintenanceEventsRepository.create`/`softDelete` and `upsertReminderRule` write locally with no outbox side-effect. |
| SyncClient | `client/lib/sync/sync_client.dart` — targets dev stub with trivial bearer auth. Needs to point at the real CES-43 API + use JWT. |
| SyncConfig | `client/lib/sync/sync_config.dart` — compile-time defines for URL + bearer token. |
| Dev sync stub | `server/dev-sync-stub/` — leave untouched. |

**Git start:** `git fetch origin && git checkout -b cursor/ces-44-<suffix> origin/main`

---

## Goal

Wire **all five backed-up tables** through the client outbox so every local write is queued for server backup. Upgrade the flush worker to target the real CES-43 API with JWT auth and implement the full retry/backoff policy from `sync-protocol.md`.

Concretely:

1. Add outbox enqueue to `VehiclesRepository` (create, update, softDelete, archive, unarchive)
2. Add outbox enqueue to `SettingsRepository` (update, bootstrap — enqueue on first real update, not on bootstrap)
3. Add outbox enqueue to `MaintenanceEventsRepository` (create, softDelete) and rule mutations (upsertReminderRule)
4. Upgrade `SyncClient` to use JWT from auth (not just bearer token string)
5. Upgrade `OutboxFlushWorker` with exponential backoff, 429 `Retry-After` handling, and automatic periodic flushing
6. Coalesce pending mutations per `sync-protocol.md` §Fill-up lifecycle (already done for fill-ups; verify for other tables)

---

## Locked decisions (do not re-litigate)

### 1. Transaction wrapping: repo write + outbox enqueue in one Drift transaction

This pattern already exists in `FillUpsRepository`. Replicate it exactly:

```dart
await _db.transaction(() async {
  // 1. Local table write
  // 2. Outbox enqueue (enqueueInsert / enqueueUpdate / enqueueSoftDelete)
});
```

A crash between the two must never leak a local write that was never queued for backup.

### 2. OutboxRepository is the single enqueue surface

Do not create parallel enqueue paths. All repositories call the existing `OutboxRepository.enqueueInsert` / `enqueueUpdate` / `enqueueSoftDelete`. The `table` string for each:

| Repository | Wire table name |
|------------|----------------|
| `FillUpsRepository` | `'fill_ups'` (already wired) |
| `VehiclesRepository` | `'vehicles'` |
| `SettingsRepository` | `'settings'` |
| `MaintenanceEventsRepository` | `'maintenance_events'` |
| `MaintenanceEventsRepository` (rules) | `'maintenance_rules'` |

These match the outbox `table` CHECK constraint values.

### 3. Payload shape per sync-protocol.md

The `payload` JSON map sent in each outbox row must match what `POST /api/v1/mutations` expects. The server assigns `user_id`, `row_version`, and `updated_at` — the client sends `updated_at` and `mutation_id` for bookkeeping but the server overwrites them. Do NOT include `user_id` or `row_version` in the payload.

Follow the exact pattern from `FillUpsRepository._payload()`:
- Include all domain columns + `id` + `updated_at` + `deleted_at` + `mutation_id`
- Exclude `user_id` and `row_version` (server-assigned)

### 4. Settings: enqueue on update, not on bootstrap

`SettingsRepository._bootstrap()` creates a default row on a fresh install with no `user_id`. This row has never been on the server. The outbox enqueue should happen on `update()`, which is the first user-intentional write. `_bootstrap()` must NOT enqueue — the server creates the settings row when the user first syncs (or the client sends it as an `insert` on first real update).

Design: when `update()` is called:
- If `row_version` is `NULL` (never synced), enqueue as `insert` (the server doesn't have this row yet)
- If `row_version` is non-NULL (server knows about it), enqueue as `update`

### 5. Vehicles: archive/unarchive are updates

`VehiclesRepository.archive()` and `unarchive()` set/clear `archived_at`. From the outbox perspective, these are `update` operations on the same row. Enqueue via `enqueueUpdate` with the full row payload.

### 6. Maintenance rules: upsert maps to insert or update

`MaintenanceEventsRepository.upsertReminderRule()` either inserts a new rule or updates an existing one. The outbox op should match: `enqueueInsert` for a new rule, `enqueueUpdate` for an existing one. The method already distinguishes these cases internally.

### 7. Exponential backoff per sync-protocol.md

Upgrade `OutboxFlushWorker` to implement the spec's retry policy:
- Backoff: `1s → 2s → 4s → 8s → 16s → 30s` (capped) with ±20% jitter
- Max 6 retries before moving to dead-letter (CES-45 surfaces these)
- HTTP 429: honor `Retry-After` header; the attempt counter increments but 429 does NOT move to dead-letter
- HTTP 401: pause outbox, trigger re-auth flow (for now, log and stop flushing)
- HTTP 5xx: retriable with backoff
- HTTP 400/403/409: non-retriable, move to dead-letter immediately

### 8. SyncClient upgrade

Point `SyncClient` at the real CES-43 API (JWT-based). The `SyncConfig` should accept a JWT token instead of (or in addition to) the static bearer token. The JWT comes from the auth layer (which is not fully built yet — for now, keep the compile-time define pattern but document that CES-45 or a future auth ticket will provide the real token flow).

Add `GET /api/v1/changes` and `GET /api/v1/restore/manifest` methods to `SyncClient` — they will be needed by CES-45 (restore) but the HTTP plumbing belongs here.

### 9. Automatic periodic flush

Add a periodic flush mechanism (e.g. a `Timer` in `OutboxFlushWorker`) that attempts to drain the outbox every 30 seconds when the app is in the foreground and `SyncConfig.isConfigured` is true. The manual "Sync now" button on the Debug page must still work. Cancel the timer when the app goes to background.

---

## Scope (in)

1. **`VehiclesRepository`** — add `OutboxRepository` dependency. Wrap `create`, `update`, `softDelete`, `archive`, `unarchive` in transactions with outbox enqueue. Build `_payload()` method mirroring `FillUpsRepository._payload()`.
2. **`SettingsRepository`** — add `OutboxRepository` dependency. Wrap `update` with outbox enqueue (insert if never-synced, update if synced). Do NOT enqueue on `_bootstrap()`.
3. **`MaintenanceEventsRepository`** — add `OutboxRepository` dependency. Wrap `create` and `softDelete` for events, and `upsertReminderRule` for rules, with outbox enqueue. Two wire tables: `'maintenance_events'` and `'maintenance_rules'`.
4. **`SyncClient`** — add `getChanges(table, since, limit)` and `getRestoreManifest()` methods. Keep `postMutations` as-is. Update auth header handling to support JWT.
5. **`OutboxFlushWorker`** — implement exponential backoff with jitter per locked decision 7. Add 429 `Retry-After` handling. Add periodic flush timer per locked decision 9. Add dead-letter threshold (6 retries → mark row as dead-lettered for CES-45).
6. **`SyncConfig`** — review/update for JWT compatibility (the compile-time define may stay for dev, but the config should support runtime token injection for when real auth lands).
7. **Tests** — for each modified repository:
   - Existing tests must still pass (all repo operations still work locally)
   - New tests verifying outbox rows are created alongside local writes
   - Transaction atomicity: verify that if the outbox enqueue fails, the local write is also rolled back
   - Coalescing: verify `enqueueUpdate` coalesces with pending `insert` for the same row
   - `softDelete` supersedes pending `insert`/`update`
   - Settings: bootstrap does NOT enqueue; update does enqueue
   - Flush worker: backoff timing, 429 handling, dead-letter threshold
8. **`client/test/sync/`** — expand existing test coverage for the upgraded flush worker.

## Scope (out)

- **Restore flow** (CES-45 — this ticket only adds the `SyncClient` methods for it)
- **Dead-letter UX** (CES-45 — this ticket only marks rows as dead-lettered)
- **Real auth / sign-in UI** (future ticket — this keeps compile-time defines)
- **Server code changes** (CES-43 API is complete)
- **Schema migration** (no new tables or columns needed)
- **Telemetry emission** (CES-46)
- **Portal / browser client** (gated on M3 + ADR 006)

## Constraints

- No schema migration. The `outbox` table schema from the gate slice is sufficient.
- All existing tests must continue to pass. Repositories that previously had no outbox dependency must work with `outbox: null` in test harnesses that don't need sync verification (provide a default no-op or make the parameter optional).
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` all green.
- The dev sync stub (`server/dev-sync-stub/`) is untouched and the E2E test (`CESTOVNI_E2E=1`) still works.
- No new runtime permissions. No new pub dependencies (unless `SyncClient` needs a JWT decode library — if so, justify).

## Acceptance

- [ ] `VehiclesRepository.create`/`update`/`softDelete`/`archive`/`unarchive` all enqueue to outbox in the same Drift transaction.
- [ ] `SettingsRepository.update` enqueues to outbox (insert if never-synced, update if synced). `_bootstrap()` does NOT enqueue.
- [ ] `MaintenanceEventsRepository.create`/`softDelete` enqueue to outbox (`maintenance_events` table). `upsertReminderRule` enqueues insert or update to outbox (`maintenance_rules` table).
- [ ] Outbox coalescing works for all tables: pending insert + update → payload rewritten; softDelete supersedes pending insert/update.
- [ ] `SyncClient` has `getChanges()` and `getRestoreManifest()` methods (ready for CES-45).
- [ ] `OutboxFlushWorker` implements exponential backoff `1s → 2s → 4s → 8s → 16s → 30s` with ±20% jitter.
- [ ] 429 responses honor `Retry-After` header; do NOT dead-letter on 429.
- [ ] Rows with ≥6 failed non-429 retries are marked as dead-lettered.
- [ ] Periodic flush (30s foreground timer) works; manual "Sync now" still works.
- [ ] Existing fill-up outbox tests still pass. New tests cover vehicles, settings, maintenance events, maintenance rules.
- [ ] Transaction atomicity verified: outbox failure rolls back the local write.
- [ ] `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` green.
- [ ] `delivery-plan-v1.md` CES-44 row → 🟩.
- [ ] Linear CES-44 Done + closeout comment.

## Status report (required)

1. Which repositories were modified and the outbox integration pattern used
2. Settings enqueue logic (insert vs update decision, bootstrap exclusion)
3. Maintenance rules upsert → outbox mapping
4. Flush worker upgrade: backoff curve, 429 handling, dead-letter threshold
5. `SyncClient` new methods (changes + manifest)
6. Test coverage summary (tables × operations × outbox assertions)
7. Known limits (e.g. no real auth token yet, dead-letter UX deferred to CES-45)
8. PR URL + Linear CES-44 state

Tag: `CES-44 — Client outbox expansion`.
