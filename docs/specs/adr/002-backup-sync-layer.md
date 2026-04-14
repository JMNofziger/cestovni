# ADR 002: Backup / sync layer (v1 backup + v1.x live sync)

**Status:** Proposed (pending explicit product/engineering sign-off)  
**Date:** 2026-04-13  
**Linear:** CES-24  

## Context

- **v1:** offline-first logging; **cloud backup/restore** of **structured** data for signed-in users; **no** server backup of ephemeral photos.
- **v1.x (directional):** near–real-time **multi-device sync**; requires explicit merge rules and likely more machinery than v1 backup.
- Risks: duplicate rows on flaky networks, partial uploads, clock skew, **draft → complete** fill-up lifecycle.

## Options considered


| Approach                              | Fit v1 backup                           | Fit v1.x live sync                    | Ops / solo maintainer                  |
| ------------------------------------- | --------------------------------------- | ------------------------------------- | -------------------------------------- |
| **Hand-rolled outbox** + Postgres API | Strong if protocol is explicit          | Build incrementally; more custom code | Full control; you own bugs             |
| **PowerSync** (Postgres-backed)       | Viable if product supports backup-first | Strong candidate for bidirectional    | Extra dependency; evaluate license/ops |
| **ElectricSQL**                       | Evaluate sync model vs backup-only      | Alternative sync engine               | Evaluate maturity + ops                |


## Decision (proposed)

- **v1:** implement **hand-rolled outbox** (pending mutations, idempotency keys, server-assigned row versions / `updated_at`) against the API from ADR 001, with a **written protocol** in `docs/specs/sync-protocol.md`.
- **v1.x:** **revisit PowerSync or ElectricSQL** (or evolve the same outbox) **after** v1 backup is stable and merge rules are spec’d; do **not** block v1 on a full sync product.

## Rationale

- v1 does not require full CRDT/real-time sync; shipping a **correct backup** first matches the brief and reduces moving parts.
- Keeps the door open to adopt a sync layer once requirements and threat model for live sync are fixed.

## Consequences

- Team must implement **retry-safe, idempotent** server handlers and a **clear fill-up lifecycle** (draft/complete/amended) in specs.
- If a POC later shows PowerSync materially reduces code **for the same guarantees**, file a new ADR to supersede this one.

## Open questions

- Server-side **version** strategy (monotonic per row vs per table vs hybrid).
- Whether **staged restore** is cursor-based only or also snapshot checkpoints.