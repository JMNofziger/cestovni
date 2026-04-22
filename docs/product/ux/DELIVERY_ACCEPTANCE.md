# Cestovni UX delivery acceptance (MVP)

This document defines what must ship vs what can wait. Use it to prevent scope creep during implementation.

**M1 / CES-39 gate:** Close every **Open** row under **Critical gaps** in [`UX_IMPLEMENTATION_GAPS.md`](UX_IMPLEMENTATION_GAPS.md) (today: CES-54, CES-55, CES-56; CES-53 **Done** in repo + tracker) — see also [`../delivery-plan-v1.md`](../delivery-plan-v1.md) (§ M1 prerequisite).

## Global acceptance gates

- **Must ship**
  - Screen behavior matches `cestovni-views.md` for core flows.
  - Data handling aligns with `DATA_CONTRACTS.md`.
  - Empty, loading, and validation states are implemented.
  - Widget tests cover critical happy-path + validation behavior.
- **Can ship later**
  - Micro-animations and visual polish beyond baseline style system.
  - Secondary convenience actions that do not block core logging workflows.

## Log (fuel entry)

- **Must ship**
  - Create fill-up with required fields (date/time, odometer, volume, total price).
  - Draft lifecycle: save draft, resume draft, and complete draft without data loss.
  - Odometer monotonic validation with explicit reset handling.
  - Optional notes + flags (`partial/full`, `missed before`, `odometer reset`).
  - Save returns to previous context with updated list/detail.
- **Later**
  - Advanced quick-fill presets, station favorites, richer recap widgets.

## History

- **Must ship**
  - Unified ledger list for fuel + maintenance entries.
  - Month grouping and deterministic ordering.
  - Filter chips: All / Fuel / Maint.
  - Entry detail view and confirmed delete action.
- **Later**
  - Flip mode transitions and high-polish card pagination effects.

## Metrics

- **Must ship**
  - Range filter (30D / 90D / YTD / ALL).
  - Lifetime summary card with distance, spend, and economy.
  - At least one trend chart + low-data placeholder behavior.
  - Rounding and unit conversion consistent with `DATA_CONTRACTS.md`.
- **Later**
  - Additional chart variants and advanced comparative overlays.

## Maintenance

- **Must ship**
  - Create maintenance entry with category, date, odometer, and optional cost/notes.
  - Entry appears in shared history stream.
  - Reminder fields captured and persisted.
- **Later**
  - Reminder scheduling UX and proactive notification surfaces.

## Settings & vehicles

- **Must ship**
  - Update distance/volume units and currency.
  - Vehicle add/edit/list flow.
  - Default vehicle setting.
- **Later**
  - Export UX improvements and destructive reset tooling (if not already available).

## Test minimums by phase

Testing depth for MVP is **balanced**: core happy paths plus key edge cases. Do not block release on exhaustive combinatorial coverage.

- **Widget tests**
  - Form required-field validation.
  - Save success path and state refresh.
  - Draft save/resume/complete flow.
  - Empty state rendering for no-vehicle / no-entry cases.
  - Fill-up flags visible with helper text (`isFull`, `missedBefore`, `odometerReset`).
- **Unit/repository tests**
  - Aggregation math for metrics ranges.
  - Unit conversion + rounding rules from `DATA_CONTRACTS.md`.
  - Delete semantics (soft delete visibility rules).
  - Deterministic history ordering tie-break (`event_datetime`, `created_at`, `id`).
  - Maintenance totals include only rows with date + cost.
  - Date-only maintenance entries remain stable as local calendar dates.

## Rollback posture

- Guard incomplete features behind navigation or visibility flags when needed.
- Avoid destructive schema changes without migration verification in test fixtures.
- If release risk appears, prioritize disabling incomplete screens over shipping inconsistent behavior.