# Cestovni — View & Behavior Spec

This document is the design-to-delivery reference for app screens. It is intentionally framework-agnostic and uses current Flutter file anchors where implemented.

Use this together with:

- `DELIVERY_ACCEPTANCE.md` for must-ship vs later scope gates
- `DATA_CONTRACTS.md` for canonical field semantics and metric rules

## Current implementation map (source of truth)

- Shell and nav scaffold: `client/lib/app/shell.dart`
- Vehicle list: `client/lib/app/pages/vehicle_list_page.dart`
- Vehicle detail + fill-up list: `client/lib/app/pages/vehicle_detail_page.dart`
- Fill-up form: `client/lib/app/pages/fill_up_form_page.dart`
- Vehicle create/edit form: `client/lib/app/pages/vehicle_form_page.dart`
- Settings: `client/lib/app/pages/settings_page.dart`

## Delivery status by screen


| Screen                      | UX target status | Implementation status | Primary file(s)                         |
| --------------------------- | ---------------- | --------------------- | --------------------------------------- |
| Log / fuel entry            | Defined          | Partial               | `fill_up_form_page.dart`                |
| History timeline + flip     | Defined          | Not started           | New page required                       |
| Metrics                     | Defined          | Not started           | New page required                       |
| Maintenance entry + history | Defined          | Not started           | New page required                       |
| Settings + vehicles         | Defined          | Partial               | `settings_page.dart`, `vehicle_*` pages |


---

## Shared chrome (all tabs)

- Header includes: brand, current date/subtitle, theme/settings actions, active vehicle context.
- Bottom nav target tabs: **Log**, **History**, **Metrics**, **Maint**.
- Visual style and component rules are defined in `cestovni-styling.md`.
- Screenshot references are under `screenshots/dark-midnight/`.

**Implementation note:** Current shell has three tabs (Home, Settings, Debug). Aligning shell nav to target tabs is a discrete development task in `client/lib/app/shell.dart`.

---

## Log a Fuel-Up

Screenshot: `screenshots/dark-midnight/log.png`

- Fast-entry form for one-handed use at pump.
- Supports quick-add and draft-save/resume lifecycle.
- Required fields: date/time, odometer, volume, total price.
- Optional fields: station, grade, notes, and data-quality flags.
- Inline validation for monotonic odometer and numeric constraints.
- Save returns to prior context and updates vehicle detail/history immediately.

**Current implementation anchors**

- Form fields and validation live in `fill_up_form_page.dart`.
- Data-quality flags stay visible in MVP: `isFull`, `missedBefore`, `odometerReset`.
- Each flag must include helper text explaining consumption impact.

**Scope gate**

- Must ship: required fields + validation + save flow + draft save/resume.
- Later: quick-fill shortcuts, station/grade intelligence.

---

## History

Screenshots: `screenshots/dark-midnight/history.png`, `screenshots/dark-midnight/history-flip.png`, `screenshots/dark-midnight/history-fuel.png`

- Default mode: grouped monthly timeline with lightweight row density.
- Alternate mode: flip-card detail with previous/next controls.
- Filter chips: All / Fuel / Maint.
- Entry tap opens full-detail view with delete action and confirmation (delete is soft-delete in v1).
- Empty states are explicit and non-blocking.
- Ordering is deterministic: event datetime DESC, then `created_at` DESC, then `id` DESC.

**Implementation note:** No dedicated history page exists yet. Add page + state model + grouping/query layer before visual polish.

**Scope gate**

- Must ship: unified stream, month grouping, filter chips, detail + delete confirm.
- Later: advanced transitions and rich flip-mode polish.

---

## Metrics

Screenshot: `screenshots/dark-midnight/metrics.png`

- Range toggle: 30D / 90D / YTD / ALL.
- Lifetime headline card and compact stat tiles.
- Charts: cost trend, economy trend, and category splits.
- Explicit placeholders for low-data states.
- Canonical first chart in MVP is **Cost over time**.
- Maintenance totals include only entries with both date and cost.

**Implementation note:** No metrics page exists yet. Define metrics contracts first (aggregation windows, rounding, partial-fill handling), then UI.

**Scope gate**

- Must ship: range filter + lifetime card + minimum one trend + low-data placeholders.
- Later: extra chart variants and comparative overlays.

---

## Maintenance

Screenshot: `screenshots/dark-midnight/maint.png`

- Form fields: date, odometer, category, shop, cost, notes.
- Optional reminders by distance and/or months.
- Save writes maintenance entry to shared ledger and future reminder logic.
- Date-only maintenance values are treated as local calendar dates (no timezone shifting).

**Implementation note:** No maintenance form/history page exists yet. Data model + repository support should land before page build.

**Scope gate**

- Must ship: entry create/save + shared history visibility + reminder fields persistence.
- Later: reminder scheduling UX and proactive alerts.

---

## Settings

Screenshot: `screenshots/dark-midnight/settings.png`

- Preferences: theme, units, currency, default vehicle.
- Vehicle management list with add/edit/delete.
- Data actions (export, destructive reset) are visible and explicit.

**Current implementation anchors**

- Preferences currently implemented in `settings_page.dart` (distance/volume/currency/timezone).
- Vehicle CRUD is implemented across `vehicle_list_page.dart`, `vehicle_detail_page.dart`, and `vehicle_form_page.dart`.
- Export/reset are not yet implemented in current settings UI.

**Scope gate**

- Must ship: units, currency, default vehicle, vehicle CRUD.
- Later: export UX refinements and destructive reset flow hardening.

---

## Empty states

- No vehicles: guided CTA to create first vehicle.
- No entries: lightweight copy, no dead ends.
- Metrics low-data: card placeholders that preserve layout.

---

## Pre-build checklist for each new UX screen

- Define data contract (inputs, derived fields, unit conversions, edge cases).
- Define acceptance criteria tied to this doc and screenshot references.
- Add test plan (widget tests + repository/unit tests for math/aggregation).
- Confirm empty/error/loading states before implementation starts.