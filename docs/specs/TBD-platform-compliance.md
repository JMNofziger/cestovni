# TBD: Platform and compliance (v1)

Stub for **Epic CES-8**. Replace “TBD” in filename when stable.

**Workflow:** Stage gates in [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md).  
**Architecture:** [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`adr/`](adr/).

## Architecture outline

- **Client:** cross-platform mobile; offline-first SQLite; ephemeral local photos (no server backup).
- **API:** see **ADR 001** — [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md) (proposed).
- **Data stores:** Postgres (authoritative structured backup); local SQLite (device).
- **Auth:** unlocks backup/restore; optional account per product direction.

## Regulatory / data

- **PII:** vehicle identifiers, optional VIN, location/EXIF on photos (local only until deleted) — to be enumerated.
- **Jurisdiction / GDPR notes:** export (ZIP), deletion, honesty that **photos are not cloud-backed**.
- **Payments (if any):** donations optional — store policy alignment.

## Open questions

- Data residency target for Postgres.
- Minors / COPPA if age gating is required.
