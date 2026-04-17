# TBD: Platform and compliance (v1)

Stub for **Epic CES-8**. Replace “TBD” in filename when stable.

**Workflow:** Stage gates in [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md).  
**Architecture:** [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`adr/`](adr/).

## Architecture outline

- **Client:** cross-platform mobile; offline-first SQLite; ephemeral local photos (no server backup).
- **API:** see **ADR 001** — [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md) (Accepted 2026-04-14).
- **Backup protocol:** see **ADR 002** — [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md) (Accepted 2026-04-17) + [`sync-protocol.md`](sync-protocol.md).
- **Data stores:** Postgres (authoritative structured backup); local SQLite (device).
- **Auth:** unlocks backup/restore; optional account per product direction.
- **Continuity mode:** backend-only self-host path for technical users (managed-first remains default operation).

## Regulatory / data

- **PII:** vehicle identifiers, optional VIN, location/EXIF on photos (local only until deleted) — to be enumerated.
- **Jurisdiction / GDPR notes:** export (ZIP), deletion, honesty that **photos are not cloud-backed**.
- **Payments (if any):** donations optional — store policy alignment.
- **Continuity / service cessation:** communicate how users can export and continue via self-hosted backend package.

## Open questions

- Data residency target for Postgres.
- Minors / COPPA if age gating is required.
