# Spec: Backup protocol & v1.x sync roadmap

**Status:** Draft — spec pass 1 (v1 backup protocol frozen; v1.x live-sync details still TBD).  
**Linear:** CES-31 (informed by [ADR 001](adr/001-backend-api-boundary.md) and [ADR 002](adr/002-backup-sync-layer.md))  

## Scope

- **v1:** structured data backup/restore for signed-in users — vehicles, fill-ups, maintenance, settings. Photos stay local ([`photo-pipeline.md`](photo-pipeline.md)); no server photo storage.
- **v1.x (roadmap pointer only):** live multi-device sync merge rules. Not specified in this pass.

## Principles

- **Offline-first.** The local SQLite database is the source of truth for UX; the server is durable backup. Logging must never block on network.
- **App-owned contract.** Clients talk only to the endpoints below, consistent with [ADR 001 client contract rules](adr/001-backend-api-boundary.md#client-contract-rules).
- **Server authority for ordering.** All monotonic identifiers (`row_version`) originate on the server.
- **Idempotent mutations.** Any mutation can be retried safely.
- **Deployment parity.** The same protocol runs in managed and self-host modes (ADR 001).

## Transport

- HTTPS JSON over the app-owned API from ADR 001.
- Authentication: bearer JWT using the identity claim model defined in ADR 001; `user_id` on every backed-up row is derived server-side from the token, never sent by the client.
- Error model: standard HTTP status + `{error: {code, message, retriable}}` envelope.

## Server schema (per backed-up row)

Every backed-up table carries these columns in addition to its domain columns:

| Column        | Type          | Notes                                                                                     |
|---------------|---------------|-------------------------------------------------------------------------------------------|
| `id`          | `UUID`        | Client-generated at creation time; stable across devices.                                 |
| `user_id`     | `UUID`        | Server-assigned from the auth token; RLS predicate column.                                |
| `row_version` | `BIGINT`      | Server-assigned from shared sequence `cestovni_row_version_seq`; set on insert + update.  |
| `updated_at`  | `TIMESTAMPTZ` | `DEFAULT now()`; human/debug readability; not used for ordering.                          |
| `deleted_at`  | `TIMESTAMPTZ` | `NULL` for live rows; set on soft-delete so restore stays consistent.                     |
| `mutation_id` | `UUID`        | Last client-provided idempotency key that touched the row; used for idempotent retries.   |

Ordering and cursor semantics rely on `row_version` exclusively. `updated_at` is for humans; clients must not use it to drive protocol decisions.

A single shared sequence across tables keeps a stable global "everything since cursor X" frame if needed later, and simplifies CI fixtures. Throughput implication is discussed in ADR 002 consequences.

## Client outbox (local only)

The outbox is a client-side table; it is never sent as-is to the server. Schema:

| Column         | Type          | Notes                                                                             |
|----------------|---------------|-----------------------------------------------------------------------------------|
| `id`           | `INTEGER PK`  | Local auto-increment.                                                             |
| `mutation_id`  | `TEXT` (UUID) | Generated once when the mutation is enqueued; reused on every retry.              |
| `table`        | `TEXT`        | Target table name.                                                                |
| `op`           | `TEXT`        | `insert` \| `update` \| `soft_delete`.                                            |
| `row_id`       | `TEXT` (UUID) | Target row `id`.                                                                  |
| `payload_json` | `TEXT`        | Full row payload for insert/update; null for soft_delete.                         |
| `enqueued_at`  | `TIMESTAMPTZ` | Local wall-clock; debug only.                                                     |
| `attempts`     | `INTEGER`     | Increments on each retry.                                                         |
| `last_error`   | `TEXT`        | Last error envelope for diagnostics.                                              |

- Drafts are **not** written to the outbox; only `complete` / `amended` / `soft_delete` transitions produce outbox rows (see Lifecycle below).
- Retries reuse the same `mutation_id`; the server dedupes and returns the original `row_version`.

## Endpoints (v1)

### `POST /mutations`

Batch upload of outbox entries.

Request:

```json
{
  "mutations": [
    {
      "mutation_id": "9b3...",
      "table": "fill_ups",
      "op": "insert",
      "row_id": "0d2...",
      "payload": { "vehicle_id": "…", "odometer_km": 12345, "liters": 42.1, "…": "…" }
    }
  ]
}
```

Response:

```json
{
  "results": [
    {
      "mutation_id": "9b3...",
      "row_id": "0d2...",
      "row_version": 1048,
      "server_updated_at": "2026-04-17T12:34:56Z",
      "status": "applied"
    }
  ]
}
```

- Each `result.status` is `applied` (new write) or `duplicate` (already applied — same `row_version` returned).
- Partial batches are allowed: individual results may carry `{status: "rejected", error: {...}}`. Retriable errors keep the outbox row; non-retriable errors move it to a local dead-letter list for user-visible handling.
- All mutations in a request execute in a single transaction on the server to keep `row_version` contiguous per batch.

### `GET /changes?table=…&since=…&limit=…`

Paginated catch-up / restore stream.

Response:

```json
{
  "table": "fill_ups",
  "rows": [ { "id": "…", "row_version": 1042, "updated_at": "…", "deleted_at": null, "…": "…" } ],
  "next_since": 1049,
  "has_more": true
}
```

- Server returns rows with `row_version > since`, ordered ascending, capped at `limit` (hard max enforced server-side).
- Clients persist `last_seen_row_version := next_since` **only after** the page commits to the local DB.
- Soft-deleted rows are included so clients can reconcile tombstones.

### `GET /restore/manifest`

Per-table metadata for UX progress + cold-start.

Response:

```json
{
  "tables": [
    { "table": "vehicles",   "row_count": 3,    "max_row_version": 1049 },
    { "table": "fill_ups",   "row_count": 812,  "max_row_version": 1048 },
    { "table": "maintenance","row_count": 47,   "max_row_version": 1041 },
    { "table": "settings",   "row_count": 1,    "max_row_version": 1007 }
  ]
}
```

- Used to drive the restore progress bar and to decide when core tables are "caught up enough" for the UI to unblock.

## Ordering and retry semantics

- **Ordering:** `row_version ASC` is the only ordering contract. `updated_at` ties are possible and must not be used by clients.
- **Retries:** exponential backoff (e.g. 1s → 2s → 4s → 8s, capped) with jitter; no retry on `error.retriable = false`.
- **Cursor safety:** clients commit the new cursor only after durable write of the page's rows; a mid-page crash replays the same page, deduped by `(id, row_version)` on the client.
- **Clock skew:** irrelevant to protocol decisions; server-side `row_version` is the truth.
- **Rate limits:** server may return `429` with a `Retry-After` hint; clients honor it with the normal backoff machinery.

## Fill-up lifecycle (applies to `fill_ups`; analogous patterns for other tables)

- `draft`: local-only row (e.g. user snapped a receipt but hasn't filled fields). **Never outboxed.** Draft cleanup runs with photo TTL ([`photo-pipeline.md`](photo-pipeline.md)).
- `complete`: transition triggered when required fields are saved. Enqueues one outbox row `op=insert`.
- `amended`: any subsequent edit. Enqueues an outbox row `op=update` with the full row payload (same `row_id`, new `mutation_id`).
- `soft_delete`: user removes the entry. Enqueues `op=soft_delete`; server sets `deleted_at`.

Multiple amendments queued before the first upload succeeds are **coalesced** client-side into a single `update` entry keyed by `row_id` before send, to reduce wasted writes.

## Restore flow (cold start / new device)

1. Call `GET /restore/manifest` to size the job.
2. For each core table (`vehicles`, `fill_ups`), loop `GET /changes?table=…&since=0&limit=…` until `has_more=false`.
3. Unblock the UI once `vehicles` + `fill_ups` cursors match the manifest's `max_row_version` (logging becomes usable).
4. Continue `maintenance`, `settings` in the background.
5. No snapshot checkpoints in v1; a partial restore resumes cleanly from the last committed cursor per table.

## v1.x roadmap (pointer only — TBD in this pass)

- **Field-level merge rules.** Proposed starting points: odometer `max`-wins, maintenance entries union by `id`, settings last-write-wins. To be specified before v1.x ships.
- **Push channels.** Options: long-poll on `/changes`, server-sent events, WebSocket. Decision deferred to when real-time UX requirements are set.
- **Conflict UX.** How to surface (if ever) a rejected amendment to the user. Deferred with the above.
- **Re-evaluation of managed sync runtime.** Gate defined in ADR 002 revisit gates.

## References

- [ADR 001 — Backend / API boundary](adr/001-backend-api-boundary.md)
- [ADR 002 — Backup / sync layer](adr/002-backup-sync-layer.md)
- [Architecture overview](ARCHITECTURE.md)
- [Photo pipeline (ephemeral, local-only)](photo-pipeline.md)
