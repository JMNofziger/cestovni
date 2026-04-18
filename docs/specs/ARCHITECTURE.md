# Cestovni — architecture overview (v1)

**Status:** Agreed for v1 kickoff (2026-04-17) — still evolves with future ADRs/specs.  
**Workflow:** [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md)

## System shape

```text
[Mobile app — Flutter + Drift (ADR 003)]
  SQLite via Drift (offline source of truth for structured data)
  Local filesystem (ephemeral receipt photos, TTL ~30d, not backed up)
  Client outbox → POST /mutations ; GET /changes for restore (see sync-protocol.md)
        ↓
[App-owned API contract layer] (see ADR 001)
  Stable request/response boundary across managed and self-host modes
        ↓
[Postgres + auth runtime]
  Authoritative structured rows; row_version sequence drives backup/restore ordering
```

## Decisions (source of truth)

| Topic | Document | Status |
|-------|-----------|--------|
| Backend / API boundary | [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md) | Accepted |
| Backup / sync layer | [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md) | Accepted |
| Mobile client stack | [`adr/003-mobile-stack.md`](adr/003-mobile-stack.md) | Accepted |
| Telemetry / crash SDK | [`adr/004-telemetry-crash-sdk.md`](adr/004-telemetry-crash-sdk.md) | Accepted |
| Product baseline | [`../product/PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) | Locked + change log |

## Deployment modes (continuity)

- **Managed mode (v1 default):** hosted backend runtime for fastest delivery and lower ops.
- **Self-host mode (continuity path):** technical users can run backend services themselves using the same schema and app contract.
- **Scope for continuity v1:** backend services only (API, DB, auth boundary); no promise of additional admin tooling in this phase.
- **Deployment matrix:** explicit capability/parity table in [`adr/001-backend-api-boundary.md` — Deployment matrix](adr/001-backend-api-boundary.md#deployment-matrix).
- **Client contract rules:** allowed/forbidden client surfaces in [`adr/001-backend-api-boundary.md` — Client contract rules](adr/001-backend-api-boundary.md#client-contract-rules).
- Source of truth for boundary requirements: [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md).
- Runbook tracking: `docs/specs/self-host-runbook.md` (Linear CES-33).

## Backup / restore protocol

- Decision: [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md) — hand-rolled outbox on the app-owned contract; no third-party sync runtime in v1 (preserves self-host parity).
- Protocol details: [`sync-protocol.md`](sync-protocol.md) — server-assigned `row_version` (Postgres sequence) + per-table cursor; endpoints `POST /mutations`, `GET /changes`, `GET /restore/manifest`; idempotent mutations via client `mutation_id`; cursor-paginated restore (no snapshot checkpoints in v1).
- Conflict policy v1: last-write-wins by `row_version`. Field-level merge rules are v1.x and live in `sync-protocol.md` roadmap.

## Specs (Phase 2b — complete for v1 kickoff)

Parent **CES-22**; children **CES-26–CES-32** (see [`README.md`](README.md)). Domain specs are **Complete (v1)** or **Complete for v1** (sync); see the index for status per file.

## Non-goals (v1)

- Server-side receipt photo storage or export of photos in ZIP.
- Full multi-device live sync (v1.x — after backup protocol is proven).

## Ephemeral photos (deferred entry)

- Product + diagram above: local TTL photos, not server-backed, not in export ZIP.
- Spec: [`photo-pipeline.md`](photo-pipeline.md).

## Implementation status (Stage 5)

- **M0 (2026-04-18):** Mobile shell + local Drift database on `main` — repository root [`client/`](../../client/). Matches **ADR 003** (Flutter + Drift) and **`data-model.md`** v1 client tables (`schema_version` 1, `0001_init` migration). Not yet: consumption UI (M1), export (M2), server backup (M3), Sentry wiring (M4). CI: [`ci/client-build.yml`](../../ci/client-build.yml); telemetry allow-list gate includes a **Dart source scan** for literal `Telemetry.emit` event names ([`ci/telemetry-gate.py`](../../ci/telemetry-gate.py)).

## Related compliance / ops

- [`platform-compliance-v1.md`](platform-compliance-v1.md) — privacy, deletion, export, telemetry erasure, store disclosures (v1 posture).
