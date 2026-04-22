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

## Maintenance entry contract (target)

- Required fields:
  - `vehicleId`
  - `serviceAt` (UTC date/datetime)
  - `category`
- Optional fields:
  - `odometerM`
  - `costCents`
  - `currencyCode`
  - `shop`
  - `notes`
  - reminders: `remindAtOdometerM`, `remindInMonths`

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
- Maintenance spend totals include only rows with non-null date and non-null cost.

### Economy calculation

- Economy uses full-fill segments only.
- Partial fills are stored and visible in history but excluded from economy segment calculations.
- If segment preconditions fail (missed fill, odometer reset edge case), omit segment from economy average.

## Rounding and display rules

- Monetary values: 2 decimal places for display.
- MPG / L/100km: 1 decimal place for display unless product explicitly overrides.
- Distance and volume follow unit setting; formatting consistency must match across form, history, and metrics.
- Date-only maintenance values are treated as local calendar dates (no timezone shift across display/filtering).

## Fill-up flag UX contract

- All three flags remain user-visible in MVP:
  - `isFull`
  - `missedBefore`
  - `odometerReset`
- Each flag requires helper text in the form explaining its effect on consumption quality.