# Spec: Data model (local SQLite + server Postgres)

**Status:** Stub — **blocked** until ADR 001 + 002 accepted and domain specs drafted.  
**Linear:** CES-32 (blocked by CES-23, CES-24)

## Scope

- Tables/entities for vehicles, fill-ups, maintenance, settings, outbox, photo references (local-only paths).
- Drift migrations (client) and Postgres migrations (server); alignment rules.

## References

- [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md)
- [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md)
