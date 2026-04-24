# Cestovni UX data contracts (MVP)

Canonical field semantics for UX + engineering implementation.

## Units and storage

- Distance canonical storage: meters (`odometerM`, integer).
- Volume canonical storage: microliters (`volumeUL`, integer).
- Money canonical storage: minor units (`totalPriceCents`, integer).
- Timestamps stored in UTC; UI displays local time.

All display conversion must be derived from user settings (distance, volume, currency).

## Fill-up entry contract

- Required fields:
  - `vehicleId`
  - `filledAt` (UTC datetime)
  - `odometerM`
  - `volumeUL`
  - `totalPriceCents`
  - `currencyCode` (ISO-4217 code)
- Optional fields:
  - `notes`
  - flags: `isFull`, `missedBefore`, `odometerReset`

### Fill-up validation rules

- Odometer cannot be negative.
- Volume cannot be negative.
- Price cannot be negative.
- `filledAt` cannot be >24h in future.
- Odometer must be monotonic unless `odometerReset=true`.
- `odometerReset=true` not allowed on first fill-up for a vehicle.

## Maintenance entry contract

Resolved by [CES-53](https://linear.app/personal-interests-llc/issue/CES-53) — schema v2 migration `0002_add_maintenance_events_category_shop` adds `category` + `shop` and relaxes `odometer_m` to nullable. See [../../specs/data-model.md](../../specs/data-model.md) §`maintenance_events` for the canonical schema.

- **Required in the form** (UX-level validation):
  - `vehicleId`
  - `performedAt` — when the work occurred; **stored** as a single **UTC** instant (ISO-8601 on the client; see [Performed time (maintenance)](#performed-time-maintenance) for how the user’s date or date+time maps to that value).
  - `category` — closed enum: `oil | tires | brakes | inspection | battery | fluid | other`
- **Optional in the form**:
  - `odometerM` — persisted as `NULL` when blank.
  - `shop` — persisted as `NULL` when blank; non-empty strings only (1..120 chars).
  - `notes` — up to 500 chars.
- **Blank-but-stored** (schema is `NOT NULL`; form supplies a default):
  - `costCents` → persisted as `0` when the user leaves the field blank (aggregates treat `0` as "no cost reported").
  - `currencyCode` → defaults to `settings.currency_code`; the form only prompts if the user has never chosen one.
- **Reminders** (“Remind in miles / months” fields on the entry form): stored as a `maintenance_rules` row keyed to the same `vehicle_id`, not as columns on `maintenance_events`. Creating an event can create or update the linked rule, but the rule is the source of truth for cadence. Surface the current rule state in the form when one already exists.

### Performed time (maintenance)

Normative rules for the single `performed_at` column ([`maintenance_events` in data-model.md](../../specs/data-model.md#maintenance_events)). The user does **not** type UTC; the app maps local intent to a stored instant.

**Effective timezone** for interpreting user input, deriving **civil** dates, and computing chart/range **window** boundaries: `settings.timezone` (IANA) on the [settings row](../../specs/data-model.md#settings). Use the same zone for on-screen display and for export’s derived `performed_at_local` in [export-v1.md](../../specs/export-v1.md) (`maintenance_events.csv`).

**Write path (two UI modes, one column):**

- **Date + time (UI collects a clock time):** Take the user’s local wall time in `settings.timezone` and convert to one UTC instant; persist as usual for timestamps (same *pattern* as fill-up `filledAt`: local wall time → storage UTC).
- **Date only (no clock in the UI):** Map the selected **civil date** to **12:00:00.000** on that date in `settings.timezone`, convert to UTC, then store. Rationale: avoids a phantom **calendar** shift from storing a naive `00:00Z`, and avoids **DST “missing local midnight”** on spring-forward days. The noon wall time is a **wire encoding** for the chosen day, not a claim about the actual time of service.

**Display path:** Convert the stored UTC value for display in `settings.timezone`. For rows saved in **date-only** mode, the UI **must not** show a clock (date only) so the noon anchor is not read as a real service time. For rows with a user-supplied time, show local date and time.

**Filters and metrics:** Inclusive range boundaries (e.g. `30D`, YTD) are **built** in `settings.timezone` and compared against the stored `performed_at` instant, so rows do not silently change civil day under an unchanged user timezone.

**Resolved in spec:** [CES-54](https://linear.app/personal-interests-llc/issue/CES-54) (date-only vs `TIMESTAMPTZ`); no second column or `DATE` type is introduced.

## History feed contract

- Unified stream of fill-up + maintenance entries by selected vehicle.
- Default ordering: newest first by event datetime.
- Tie-break rule for equal event datetime:
  1. `created_at` DESC
  2. `id` DESC
- Soft-deleted entries are excluded from default list views.

## Metrics contract (MVP)

- Supported ranges: `30D`, `90D`, `YTD`, `ALL`.
- Range filter applies to all displayed aggregates and charts.
- Canonical first MVP chart: **Cost over time**.
- Lifetime card includes:
  - total distance
  - total spend
  - average economy
- Low-data rule: show placeholder when fewer than 2 data points for a trend.
- Maintenance spend totals sum `cost_cents` across live events (not soft-deleted); rows where the user left cost blank contribute `0` per the maintenance entry contract above.

### Economy calculation

- Economy uses full-fill segments only.
- Partial fills are stored and visible in history but excluded from economy segment calculations.
- If segment preconditions fail (missed fill, odometer reset edge case), omit segment from economy average.

## Rounding and display rules

- Monetary values: 2 decimal places for display.
- MPG / L/100km: 1 decimal place for display unless product explicitly overrides.
- Distance and volume follow unit setting; formatting consistency must match across form, history, and metrics.
- For maintenance, **date-only** UX: civil date and filters stay stable in `settings.timezone` — see [Performed time (maintenance)](#performed-time-maintenance) (no silent shift across display/filtering while the effective zone is unchanged).

## Fill-up flag UX contract

- All three flags remain user-visible in MVP:
  - `isFull`
  - `missedBefore`
  - `odometerReset`
- Each flag requires helper text in the form explaining its effect on consumption quality.