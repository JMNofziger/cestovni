# Cestovni — View & Behavior Spec

This document is the design-to-delivery reference for app screens. It is intentionally framework-agnostic and uses current Flutter file anchors where implemented.

Use this together with:

- `DELIVERY_ACCEPTANCE.md` for must-ship vs later scope gates
- `DATA_CONTRACTS.md` for canonical field semantics and metric rules

## Current implementation map (source of truth)

**Last synced:** 2026-05-21 (CES-39 phases 1–3; phase 3 on branch `docs/android-first-sequencing`, merge to `main` pending).

- Shell and nav: `client/lib/app/shell.dart` (Log / History / Metrics / Maint + header)
- Active vehicle: `client/lib/app/active_vehicle.dart`
- Repositories: `client/lib/db/repositories/` (vehicles, fill-ups, drafts, settings)
- Consumption validation: `client/lib/consumption/` (wired on Log save + History amend)
- Log / History: `pages/log_page.dart`, `pages/history_page.dart` (CES-39 phase 3)
- Vehicle CRUD: `pages/vehicle_form_page.dart` + list in `pages/settings_page.dart` (phase 2)
- Settings: vehicle list wired; units/currency/default vehicle wired (**CES-57**)
- Metrics: `pages/metrics_page.dart` (**CES-66** — range filter + summary + cost chart; aggregation in `client/lib/metrics/`, display units in `client/lib/units/`)
- Maint tab: `pages/maintenance_page.dart` (stub)
- Debug: `pages/debug_page.dart`

## Delivery status by screen


| Screen                      | UX target status | Implementation status | Primary file(s)                                           |
| --------------------------- | ---------------- | --------------------- | --------------------------------------------------------- |
| Log / fuel entry            | Defined          | **Shipped** (phase 3) | `pages/log_page.dart` — form, draft, `validateInsert`     |
| History timeline            | Defined          | **Shipped** (fuel)    | `pages/history_page.dart` — list, detail, edit, delete; MAINT chip disabled; flip mode later |
| Metrics                     | Defined          | **Shipped** (CES-66)  | `pages/metrics_page.dart` — range filter, summary card, cost-over-time chart, low-data placeholders |
| Maintenance entry + history | Defined          | Stub                  | `pages/maintenance_page.dart`                             |
| Settings                    | Defined          | **Shipped** (CES-57)  | `pages/settings_page.dart` — vehicle CRUD + units/currency/timezone/default vehicle |
| Vehicle CRUD                | Defined          | **Shipped** (phase 2) | `pages/vehicle_form_page.dart`                            |


---

## Shared chrome (all tabs)

- Header includes: brand, current date/subtitle, theme/settings actions, active vehicle context.
- Bottom nav target tabs: **Log**, **History**, **Metrics**, **Maint**.
- Visual style and component rules are defined in `cestovni-styling.md`.
- Screenshot references are under `screenshots/dark-midnight/`.

**Implementation note:** Shell from CES-56; Log, History (CES-39 phase 3), and Metrics (CES-66) tabs are live. Maint remains a stub page. Settings (gear) is a pushed route; Debug from Settings. Theme toggle is local; first-load default **dark** per `cestovni-styling.md` §5.

### Active vehicle (session state)

- The header vehicle chip reads live vehicles from the `vehicles` table (`deleted_at IS NULL AND archived_at IS NULL`), ordered by `name`.
- "Active vehicle" lives in memory for the session (`ActiveVehicle` / `ActiveVehicleScope` in `client/lib/app/active_vehicle.dart`). It persists across tab switches but resets on cold-start; that is the M1 contract.
- On launch `settings.default_vehicle_id` (CES-57) is selected if it still resolves to a live vehicle; otherwise the first live vehicle (alphabetical) wins. See `client/lib/app/shell.dart#_seedActiveVehicle`. If the active id no longer matches a live row (vehicle archived/deleted on another device → re-sync) the chip falls back to the first live vehicle on the next stream emission.
- If there are no live vehicles the chip shows `NO VEHICLE`. Log/History show **GO TO SETTINGS** empty state (CES-39).
- `settings.default_vehicle_id` is set from Settings → Preferences → **Default vehicle** (CES-57).

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

**Implementation note:** Shipped (**CES-66**). Range windows / summary / cost series computed in `client/lib/metrics/metrics_aggregation.dart` (pure, reuses `client/lib/consumption/` segment math); UI in `pages/metrics_page.dart` with a minimal custom-painter polyline (no chart dependency). MVP ships the cost-over-time chart only; economy trend + category splits are Later. Mixed currencies render one series per currency (deep fix CES-51); non-UTC IANA timezones approximate window boundaries with the device offset until a tz database lands.

**Scope gate**

- Must ship: range filter + lifetime card + minimum one trend + low-data placeholders.
- Later: extra chart variants and comparative overlays.

---

## Maintenance

Screenshot: `screenshots/dark-midnight/maint.png`

- Form fields: `performedAt` (date/time), optional odometer, required category, optional shop, cost (blank → stored as `0` cents), optional notes — see `DATA_CONTRACTS.md` §Maintenance entry contract.
- If the form collects **date only** (no clock), the stored `performed_at` instant follows `DATA_CONTRACTS.md` § [Performed time (maintenance)](DATA_CONTRACTS.md#performed-time-maintenance) (local noon anchor, date-only in the UI; no phantom calendar shift under an unchanged `settings.timezone`).
- Optional reminders by distance and/or months — persisted on `maintenance_rules` (not as columns on `maintenance_events`).
- Save writes maintenance entry to shared ledger; reminder cadence follows the rule row contract in `data-model.md`.

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