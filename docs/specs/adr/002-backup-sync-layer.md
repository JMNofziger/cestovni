# ADR 002: Backup / sync layer (v1 backup + v1.x live sync)

**Status:** Accepted  
**Date:** 2026-04-13  
**Accepted on:** 2026-04-17  
**Linear:** CES-24  

## Context

- **v1:** offline-first logging; **cloud backup/restore** of **structured** data for signed-in users; **no** server backup of ephemeral photos.
- **v1.x (directional):** near–real-time **multi-device sync**; requires explicit merge rules and likely more machinery than v1 backup.
- Risks: duplicate rows on flaky networks, partial uploads, clock skew, **draft → complete** fill-up lifecycle.
- Must preserve the **app-owned API contract** boundary from [ADR 001](001-backend-api-boundary.md) so managed and self-host modes run the same protocol.

## Options considered

| Approach                              | Fit v1 backup                           | Fit v1.x live sync                    | Ops / solo maintainer                  |
| ------------------------------------- | --------------------------------------- | ------------------------------------- | -------------------------------------- |
| **Hand-rolled outbox** + Postgres API | Strong if protocol is explicit          | Build incrementally; more custom code | Full control; you own bugs             |
| **PowerSync** (Postgres-backed)       | Viable if product supports backup-first | Strong candidate for bidirectional    | Extra dependency; evaluate license/ops |
| **ElectricSQL**                       | Evaluate sync model vs backup-only      | Alternative sync engine               | Evaluate maturity + ops                |

## Decision

- **v1:** implement a **hand-rolled outbox** (client-side) + **stateless HTTPS mutation/changes API** against the ADR 001 app-owned contract. Written protocol lives in [`docs/specs/sync-protocol.md`](../sync-protocol.md).
- **v1.x:** **revisit PowerSync / ElectricSQL** (or evolve the same outbox) **after** v1 backup is stable in production and merge rules are spec'd. Filed as an explicit revisit gate below rather than an aspirational note.

## Rationale

- v1 does not require CRDT/real-time semantics; shipping a **correct backup** first matches the product brief and minimizes moving parts.
- A third-party sync runtime would become a **required service in self-host mode**, undermining the ADR 001 continuity promise ("backend services only" in the self-host capability table). Hand-rolling keeps the self-host stack to Postgres + app API.
- Keeps client-side code free of provider-specific sync SDKs, consistent with the ADR 001 client contract rules.
- Door stays open to supersede this ADR with a new one if v1 experience proves a managed sync runtime is materially cheaper/safer.

## Protocol primitives (v1)

Full details in [`docs/specs/sync-protocol.md`](../sync-protocol.md); the ADR fixes these decisions:

- **Server-assigned versioning — hybrid:**
  - Every backed-up row carries a monotonic `row_version BIGINT` assigned from a Postgres sequence (`cestovni_row_version_seq`) on insert/update.
  - Rows also carry `updated_at TIMESTAMPTZ DEFAULT now()` for human readability and tie-breakers.
  - `row_version` is the **ordering source of truth**; `updated_at` never drives protocol decisions.
- **Change cursors — per table:** clients track `(table, last_seen_row_version)` and page with `WHERE row_version > :since ORDER BY row_version ASC LIMIT :page`.
- **Idempotency keys:** every client-originated mutation carries a client-generated `mutation_id` (UUID). Server enforces uniqueness so retries of the same mutation are safe and return the previously assigned `row_version`.
- **Endpoints (stable contract):**
  - `POST /mutations` — batch upserts + soft-deletes; server assigns `row_version` and `updated_at`.
  - `GET /changes?table=…&since=…&limit=…` — paginated restore/catch-up stream.
  - `GET /restore/manifest` — per-table row counts and current max `row_version` for progress UX.
- **Soft delete:** removals are represented by `deleted_at` rather than physical delete, so restore on a new device reconstructs a consistent state.

## Conflict policy (v1)

- **Last-write-wins by `row_version`** at the row level. The server is the authority; clients never fabricate `row_version`.
- **Why it is acceptable for v1:** the product brief scopes v1 as backup/restore (effectively single-device). Real concurrent edits require v1.x live sync.
- **What v1.x will need (out of scope here, tracked in `sync-protocol.md`):** field-level merge rules (e.g. odometer `max`-wins), union semantics for maintenance lists, explicit conflict UX.

## Restore strategy (v1)

- **Cursor-paginated only.** Restore streams `GET /changes` per table in `row_version` order until the client's cursor catches the manifest's current max.
- **No snapshot checkpoints in v1.** Dataset per user is small (one person's fuel/maintenance history); checkpoints would add storage + GC complexity without evidence they are needed.
- **Logging is never blocked on full download** (brief requirement). The client marks the local DB usable once the core tables (vehicles, fill_ups) have caught up; maintenance/settings can continue in the background.

## Deployment parity

- Same protocol runs in both deployment modes defined in [ADR 001 — Deployment matrix](001-backend-api-boundary.md#deployment-matrix). The only protocol dependency is a standard Postgres sequence; no provider-specific features are used.
- Restore smoke tests from ADR 001's CI promotion gates exercise `POST /mutations` + `GET /changes` against both managed and self-host fixtures.

## Consequences

- Team must implement **retry-safe, idempotent** server handlers and a **clear fill-up lifecycle** (draft/complete/amended) in specs.
- Server-side sequence becomes a shared hotspot; write throughput is bounded by its increment rate. Acceptable for v1 scale (single-user backup); revisit if throughput budgets tighten.
- No third-party sync runtime in v1 means no vendor SLA to rely on for durability — backup correctness rests on Postgres + our tests. Mitigated by ADR 001's restore smoke gate.

## Revisit gates (explicit, not aspirational)

- **PowerSync / ElectricSQL re-evaluation:** after v1 backup has been in production long enough to produce real bug + complexity data, or when v1.x live sync scope is approved. A superseding ADR must show the new runtime reduces code **for the same or stronger guarantees** and remains deployable in self-host mode (or the continuity promise is explicitly renegotiated via the product brief change log).
- **Snapshot checkpoints:** add only if observed restore time on real user datasets exceeds a defined budget (to be set during v1 soak).

## Acceptance evidence

- Protocol primitives frozen in this ADR and expanded in [`docs/specs/sync-protocol.md`](../sync-protocol.md) (spec pass 1).
- Conflict policy and restore strategy decided in this ADR; v1.x merge rules deferred with a named owner document (`sync-protocol.md` roadmap section).
- Deployment parity cross-referenced with [ADR 001 — Deployment matrix](001-backend-api-boundary.md#deployment-matrix); no new self-host dependencies.
- Product/workflow alignment captured in [`docs/product/PRODUCT_BRIEF.md`](../../product/PRODUCT_BRIEF.md) change log and [`docs/product/PRODUCT_DEV_WORKFLOW.md`](../../product/PRODUCT_DEV_WORKFLOW.md) Stage 2 Step 3.

## Follow-ups (tracked outside this ADR)

- `sync-protocol.md` v1.x pass: field-level merge rules, push channels, conflict UX.
- `data-model.md`: concrete table list with the columns this ADR requires (`row_version`, `updated_at`, `deleted_at`, `mutation_id` outbox).
- Linear issue for the v1.x sync re-evaluation gate so the deferral is visible on the board.
