# Spec: Data model (local SQLite + server Postgres)

**Status:** Stub — unblocked by ADR 001 + 002 (both Accepted); awaiting domain-spec closure before a concrete schema pass.  
**Linear:** CES-32

## Scope

- Tables/entities for vehicles, fill-ups, maintenance, settings, and the client-local outbox (photo references stay local-only).
- Drift migrations (client) and Postgres migrations (server); alignment rules.
- Every backed-up table must carry the protocol columns fixed by ADR 002: `id UUID`, `user_id UUID`, `row_version BIGINT` (from sequence `cestovni_row_version_seq`), `updated_at TIMESTAMPTZ`, `deleted_at TIMESTAMPTZ NULL`, `mutation_id UUID`.

## Prerequisites for the next pass

- Domain-spec closure for consumption/fill-up lifecycle ([`consumption-math.md`](consumption-math.md)) and ephemeral photos ([`photo-pipeline.md`](photo-pipeline.md)) so concrete columns are known.
- SI canonical column rules from [`si-units.md`](si-units.md) applied consistently in the schema.

## References

- [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md) — Accepted
- [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md) — Accepted
- [`sync-protocol.md`](sync-protocol.md) — v1 backup protocol (spec pass 1)
