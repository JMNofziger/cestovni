# Cursor execution prompt — CES-67 Maintenance tab UI + repository

> **Status: EXECUTED** (2026-08-15) — shipped on `main` (PR #17).
> Linear **[CES-67](https://linear.app/personal-interests-llc/issue/CES-67)** is **Done**.
> Next coding: **CES-41** (export). Parallel ops: **CES-68** (APK) / **CES-63** (iPhone install-doc).

**Branch:** `cursor/ces-67-maintenance-2aaa` from `main`
**Linear:** [CES-67](https://linear.app/personal-interests-llc/issue/CES-67)
**Spec:** `docs/specs/data-model.md` §`maintenance_events` / §`maintenance_rules` + `docs/product/ux/DATA_CONTRACTS.md` §Maintenance
**UX refs:** `docs/product/ux/cestovni-views.md` §Maintenance / §History · `docs/product/ux/DELIVERY_ACCEPTANCE.md` §Maintenance

## Goal

Replace the Maintenance tab stub and enable the History **Maint** chip:

1. `MaintenanceEventsRepository` create / list / soft-delete (local only — no outbox)
2. Entry form: category, date-only `performedAt`, optional odometer/shop/cost/notes
3. Reminder **fields** persist on `maintenance_rules` (distance and/or months) — **not** scheduling UX
4. Shared History stream: All / Fuel / Maint chips

Must work **offline**. Do not touch PWA-lite, sync, or server.

## Scope (out)

- Reminder scheduling / notifications
- Maintenance outbox (M3 / CES-44)
- Flip-card History mode
- PWA-lite Maint
- Photo pipeline (CES-40)

## Date-only write path

`DATA_CONTRACTS.md` §Performed time: civil date → **12:00** in `settings.timezone` → UTC. Same tz approximation as CES-66 (`UTC` exact; other IANA names use device offset). Display date only — do not show the noon clock.

## Tests

- Repository: create, list excludes other vehicles + soft-deleted, reminder rule upsert
- `performedAt` date-only helper
- Ledger merge ordering
- Widget: save on Maint tab; History Maint chip shows the row

## Docs closeout

Update `delivery-plan-v1.md` CES-67 → 🟩; `cestovni-views.md` Maint + History implementation notes.
