# Cestovni — architecture overview (v1)

**Status:** Draft — evolves with ADRs and specs.  
**Workflow:** [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md)

## System shape

```text
[Mobile app — Flutter/RN TBD]
  SQLite (offline source of truth for structured data)
  Local filesystem (ephemeral receipt photos, TTL ~30d, not backed up)
  Outbox → backup upload when online
        ↓
[Postgres + auth] (see ADR 001)
  Authoritative structured rows for signed-in backup/restore
```

## Decisions (source of truth)

| Topic | Document | Status |
|-------|-----------|--------|
| Backend / API boundary | [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md) | Proposed |
| Backup / sync layer | [`adr/002-backup-sync-layer.md`](adr/002-backup-sync-layer.md) | Proposed |
| Product baseline | [`../product/PRODUCT_BRIEF.md`](../product/PRODUCT_BRIEF.md) | Locked + change log |

## Specs (Phase 2b)

Parent **CES-22**; children **CES-26–CES-32** (see `docs/specs/README.md`). Files are stubs until each issue is closed.

## Non-goals (v1)

- Server-side receipt photo storage or export of photos in ZIP.
- Full multi-device live sync (v1.x — after backup protocol is proven).

## Related compliance / ops

- [`TBD-platform-compliance.md`](TBD-platform-compliance.md) — privacy, deletion, data residency notes.
