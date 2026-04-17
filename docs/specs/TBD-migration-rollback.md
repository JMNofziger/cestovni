# Spec stub: Client schema migration rollback tooling

**Status:** Stub (Stage 5) — to be completed before Milestone 5 (M5) starts. This stub exists because the brief change log (2026-04-17) explicitly defers client schema migration rollback tooling to Stage 5.

**Workflow:** [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md) Stage 5 Step 11 (M5).
**Delivery plan:** [`../product/delivery-plan-v1.md`](../product/delivery-plan-v1.md) vertical 12.
**Related specs:** [`data-model.md`](data-model.md), [`sync-protocol.md`](sync-protocol.md), [ADR 002](adr/002-backup-sync-layer.md).

---

## Problem

A bad client schema migration can brick the offline app on real devices. Users cannot "uninstall a migration" cleanly in SQLite. We need a documented, tested **downgrade path** before we tell testers to update, and a recovery story for the edge case where an already-upgraded device must revert.

## In scope (v1)

- **Versioned migrations:** every schema change ships with an `UP` and a matching `DOWN` script; the chosen client ORM (Drift per [ADR 003](adr/003-mobile-stack.md)) must commit both.
- **Local pre-migration snapshot:** before running an `UP` migration, the client writes a point-in-time SQLite snapshot under the app sandbox (size-capped; sibling file to live DB).
- **In-app recovery action:** hidden-until-needed `Settings → Advanced → Restore from pre-migration snapshot` that swaps the live DB for the snapshot and replays the outbox against the older schema.
- **Outbox replay compatibility:** outbox entries must survive a rollback; [`sync-protocol.md`](sync-protocol.md) already treats mutations as idempotent, but we need fixture tests proving a rollback + replay converges.
- **CI coverage:** a `tests/migrations/` directory with fixtures per migration pair; CI runs `UP` then `DOWN` then re-`UP` and asserts schema + representative rows match.

## Out of scope (v1)

- Server-side schema downgrade (server migrations are forward-only per [ADR 001](adr/001-backend-api-boundary.md) deployment matrix; we will not couple client rollback to server rollback).
- Multi-version leapfrog rollback (rollback is **one step** only in v1; repeated rollback is user-performed by repeated action).

## Open questions (fill before Complete status)

- Snapshot retention policy (keep how many?). Default proposal: keep most-recent-1 to bound disk; rolls off on next successful `UP`.
- Size cap: what do we do when the DB is larger than the snapshot budget? Default proposal: refuse migration until user exports ZIP (link [`export-v1.md`](export-v1.md)).
- UX: do we expose snapshot age and row count to the user before rollback? Default proposal: yes; read-only summary before confirmation.
- Telemetry: events `schema_migration_attempt` + `schema_migration_rollback` — should they be added to [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml)? Default proposal: yes, enum-typed outcomes only.

## Acceptance (for flipping Stub -> Complete)

- [ ] Open questions resolved in this file.
- [ ] Drift migration helpers or equivalent reviewed against the chosen pattern.
- [ ] `tests/migrations/` exists with at least one `UP`+`DOWN`+re-`UP` fixture.
- [ ] Telemetry events (if any) added to YAML + allow-list.
- [ ] Linked from `delivery-plan-v1.md` vertical 12 acceptance criteria.
