# Cursor execution prompt — CES-45 Restore + dead-letter UX

> **Status: EXECUTED** (2026-10-20) — draft [PR #36](https://github.com/JMNofziger/cestovni/pull/36), stacked on CES-44. Not on `main` until #35 and #36 merge.
> Linear **[CES-45](https://linear.app/personal-interests-llc/issue/CES-45)** Done.
> Next coding focus is **[CES-46](https://linear.app/personal-interests-llc/issue/CES-46)**. Do not start it from this prompt.
>
> Kept as an archive of the execution brief (do not re-run). Open limits are in [`../delivery-plan-v1.md`](../delivery-plan-v1.md) § M3 known gaps.

**Branch:** cut from **`main`** (after CES-44 merges)
**Spec (normative):** [`docs/specs/sync-protocol.md`](../../specs/sync-protocol.md) (§Restore flow, §Dead-letter handling)
**Also read:** [`docs/specs/adr/002-backup-sync-layer.md`](../../specs/adr/002-backup-sync-layer.md) · [`docs/specs/data-model.md`](../../specs/data-model.md) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-44** Client outbox expansion on `main` |
| M0–M2 | **Closed.** |
| M3 | **CES-42 done** (Postgres + RLS). **CES-43 done** (Server API + auth). **CES-44 done** (All 5 tables enqueue to outbox; flush worker has backoff + dead-letter threshold). |
| SyncClient | `client/lib/sync/sync_client.dart` — has `postMutations()`, `getChanges()`, and `getRestoreManifest()` (added in CES-44). |
| OutboxFlushWorker | `client/lib/sync/outbox_flush_worker.dart` — exponential backoff, 429 `Retry-After`, dead-letter threshold at 6 retries. Rows with ≥6 failed retries are marked but no UX surfaces them yet. |
| Dead-letter rows | Exist in the `outbox` table with `attempts >= 6` and `last_error` populated. No UI shows them. |
| Restore | No restore flow exists. No `RestoreService` or `RestoreWorker`. |
| Auth | Compile-time JWT token via `SyncConfig`. No sign-in UI. |

**Git start:** `git fetch origin && git checkout -b cursor/ces-45-<suffix> origin/main`

---

## Goal

Implement the **restore flow** (rehydrate local DB from server on first sign-in / reinstall) and the **dead-letter UX** (surface stuck outbox mutations to the user with replay/discard actions). Together, these close the ADR 002 backup/restore loop.

Concretely:

1. `RestoreService` that orchestrates cursor-paginated `GET /changes` per table after `GET /restore/manifest`
2. Restore progress UX: per-table progress bar, early UI unblock once core tables catch up
3. Dead-letter panel in Settings → Backup showing stuck mutations with Retry / Discard / View details
4. Integration tests proving restore convergence (local DB matches server state)

---

## Locked decisions (do not re-litigate)

### 1. Restore flow per sync-protocol.md §Restore flow

The restore algorithm, in order:

1. Call `GET /api/v1/restore/manifest` to get per-table `{row_count, max_row_version}`
2. For each **core table** (`vehicles`, `fill_ups`), loop `GET /api/v1/changes?table=…&since=0&limit=200` until `has_more=false`
3. **Unblock the UI** once `vehicles` + `fill_ups` cursors match the manifest's `max_row_version` — logging becomes usable even while background tables are still downloading
4. Continue downloading `maintenance_rules`, `maintenance_events`, `settings` in the background
5. Persist `last_seen_row_version` per table **only after** the page commits to the local DB
6. A partial restore resumes cleanly from the last committed cursor per table (no snapshot checkpoints in v1)

### 2. When restore triggers

Restore runs on:
- **First sign-in** (user authenticates on a fresh install → local DB is empty or has only bootstrapped settings)
- **Manual "Restore from backup"** from Settings → Backup (user-initiated)
- **Reinstall / data clear** (app detects `SyncConfig.isConfigured` but local tables are empty)

Detection heuristic: if `SyncConfig.isConfigured` and `vehicles` table is empty (no rows, including soft-deleted), offer restore. Do NOT automatically restore — show a confirmation dialog first.

### 3. Local write handling during restore

During an active restore:
- The user CAN still create new fill-ups / vehicles locally (offline-first principle — logging never blocks on network, per the product brief)
- New local writes go to the outbox as normal (CES-44)
- Incoming restored rows from the server are written with their server-assigned `row_version`; local rows without a `row_version` (pre-sync) are left as-is for the next outbox flush
- Conflict: if a restored row's `id` matches a local row, the server row wins (LWW by `row_version` — the server's `row_version` is always non-NULL and higher than the local `NULL`)

### 4. Cursor safety

Per `sync-protocol.md` §Ordering and retry semantics:
- Commit the new cursor only after durable write of the page's rows
- A mid-page crash replays the same page, deduped by `(id, row_version)` on the client
- Implementation: write each page's rows + update cursor in one Drift transaction

### 5. Dead-letter handling per sync-protocol.md §Dead-letter handling

Dead-letter rows are outbox entries where:
- `attempts >= 6` AND the last error was non-retriable (400, 403, 409), OR
- The `last_error` field indicates a non-retriable failure

Dead-letter contract:
- Dead-letter rows **do not block** other outbox rows from uploading (CES-44 flush worker already handles this by skipping dead-lettered rows)
- Dead-letter rows remain on the device until the user resolves them — never auto-discarded
- The failing `mutation_id` is preserved for potential future retry

### 6. Dead-letter UX per sync-protocol.md §UX hook

Surface in **Settings → Backup** (a new section or screen):

- Non-intrusive indicator when `dead_letter_count > 0` (badge on the Backup row, or a warning card)
- Show the count and a human-readable summary of the most recent failing entry (e.g. "Fill-up on April 3 couldn't be backed up — server rejected it")
- Three actions per dead-letter row:
  1. **Retry now** — re-queue with a fresh attempt counter (reset `attempts` to 0, clear `last_error`)
  2. **Discard** — hard-delete the outbox row. If it was an `insert`, leave the local row in a clearly-marked "not backed up" state (the row stays local but has no server counterpart)
  3. **View details** — show the error envelope (`last_error` content) for support/debugging

### 7. Restore progress UX

Minimal but functional:
- Full-screen overlay during initial restore (the app is not usable until core tables arrive)
- Per-table progress: `"Vehicles: 3/3 ✓"`, `"Fill-ups: 412/812..."`, `"Maintenance: waiting..."`
- Animate progress using manifest counts as denominators
- Once `vehicles` + `fill_ups` complete, dismiss the overlay and let the user into the app; show a subtle "syncing maintenance data..." indicator in the bottom bar
- Error state: if restore fails (network error, auth error), show a retry button + option to skip and use the app offline

### 8. Cursor persistence

Store per-table cursors in a new local-only table or in `settings` (or a simple key-value store). Suggested:

```sql
CREATE TABLE sync_cursors (
  table_name TEXT PRIMARY KEY,
  last_row_version INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);
```

This table is client-only (never backed up, never in outbox). If adding a table requires a schema migration, bump to v6 and add migration 0006.

### 9. Telemetry hooks (stubs only)

Per the CES-45 Linear issue acceptance: `restore_start` / `restore_result` telemetry events. Since CES-46 (telemetry wiring) hasn't shipped, add **stubs only** — call sites that log to `debugPrint` in debug mode and will be wired to the real telemetry system later. Add the event names to `docs/specs/telemetry-allowlist.md` if not already there.

---

## Scope (in)

1. **`client/lib/sync/restore_service.dart`** — orchestrates the full restore flow per locked decision 1. Uses `SyncClient.getRestoreManifest()` and `SyncClient.getChanges()`. Writes pages to the local DB via Drift transactions. Tracks per-table cursor progress.
2. **`client/lib/db/tables/sync_cursors.dart`** (if new table needed) — local-only cursor persistence. Schema migration 0006 if required.
3. **`client/lib/db/repositories/sync_cursors_repository.dart`** — read/write per-table cursor values.
4. **Restore UI** — restore progress screen/overlay per locked decision 7. Trigger from first-sign-in detection or Settings → Backup → Restore.
5. **Dead-letter UX** — Settings → Backup section per locked decision 6. List stuck mutations, show summary + error detail, Retry / Discard / View details actions.
6. **`client/lib/db/repositories/outbox_repository.dart`** — add methods for dead-letter queries:
   - `deadLetterCount()` / `watchDeadLetterCount()` — count of rows with `attempts >= 6`
   - `deadLetterRows()` — full list for the Settings panel
   - `retryDeadLetter(int id)` — reset `attempts` to 0, clear `last_error`
   - `discardDeadLetter(int id)` — hard-delete the outbox row
7. **Integration tests** — `tests/backup/` (new directory):
   - Restore convergence: seed server with known data → run restore → verify local DB matches
   - Partial restore resume: interrupt mid-table → resume → verify completion
   - Cursor safety: crash simulation → verify no duplicate rows
   - Dead-letter: create a dead-lettered row → Retry resets it → Discard removes it
8. **Widget tests** — restore progress UI rendering, dead-letter list rendering with actions.
9. **`docs/specs/telemetry-allowlist.md`** — add `restore_start` / `restore_result` event stubs (names only, no SDK wiring).

## Scope (out)

- **Real sign-in UI / auth flow** (future ticket — restore is triggered manually or by detection heuristic)
- **Push channels / real-time sync** (v1.x per ADR 002)
- **Snapshot checkpoints** (not needed for v1 per sync-protocol.md §Restore strategy)
- **Telemetry SDK wiring** (CES-46 — stubs only here)
- **Server code changes** (CES-43 API is complete)
- **Portal / browser client** (gated on ADR 006)
- **10k-row perf gate** (device timing deferred to CES-68, same as export)

## Constraints

- Offline-first: logging must never block on restore. The user can always create local entries even mid-restore.
- If a new `sync_cursors` table is added, schema migration (v5→v6) is required with proper up/down steps in `schema_steps.dart`.
- All existing tests must continue to pass.
- `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` all green.
- No new runtime permissions.
- Restore must be cancellable (user can back out and use the app offline).

## Acceptance

- [x] `GET /restore/manifest` fetched and per-table progress displayed.
- [x] Core tables (`vehicles` + `fill_ups`) restore to completion; UI unblocks.
- [x] Background tables (`maintenance_rules`, `maintenance_events`, `settings`) restore continues after UI unblock.
- [x] Per-table cursor persisted in one Drift transaction with the page rows.
- [x] Partial restore resumes from last cursor — no duplicate rows on re-run.
- [x] Local writes during restore do not conflict; new fill-ups go to outbox normally.
- [x] Dead-letter panel in Settings → Backup shows count + human-readable summaries.
- [x] Retry action resets attempts and re-queues the mutation.
- [x] Discard action hard-deletes the outbox row; local data row remains.
- [x] View details shows the error envelope.
- [x] Integration test in `tests/backup/` proves restore convergence (local DB = server state).
- [x] Restore handles network errors gracefully (retry button, not a crash).
- [x] `restore_start` / `restore_result` telemetry stubs in place (debugPrint, not SDK).
- [x] `flutter analyze` + `flutter test --no-pub` + `python3 ci/telemetry-gate.py` green.
- [x] `delivery-plan-v1.md` CES-45 row → 🟩; M3 rollup → 🟩.
- [x] Linear CES-45 Done + closeout comment.

## Status report (required)

1. Restore service design (table order, cursor tracking, transaction boundaries)
2. Schema migration (if `sync_cursors` table added — migration number, up/down)
3. Restore UX (overlay vs inline, progress indicators, error handling)
4. Dead-letter UX (where it lives, what it shows, action handlers)
5. How local writes during restore are handled (conflict resolution)
6. Integration test design (how server state is seeded, convergence assertion)
7. Telemetry stub placement
8. Known limits (e.g. no real auth, no push channels, no perf gate)
9. PR URL + Linear CES-45 state

Tag: `CES-45 — Restore + dead-letter UX`.
