# Manual test guide — CES-66 Metrics tab (+ CES-65 prefs display)

Quick manual pass for the Metrics tab and the Log/History settings-prefs wiring.
Automated coverage already exists (`cd client && flutter analyze && flutter test --no-pub`
— 185 tests green); this checklist covers what only a human on a device can confirm.

## Run the app

- **Android (primary):** `cd client && flutter run` with an emulator or USB device
  attached (Android SDK required — not present in the cloud VM; use your local machine).
- **Linux desktop (optional dev shortcut):** needs `ninja-build`, `libgtk-3-dev`,
  `libstdc++-13-dev`, then `flutter create --platforms=linux --project-name cestovni .`
  once inside `client/` (the generated `linux/` runner is not committed), then
  `flutter run -d linux`.

## Seed data (once)

1. Settings (gear) → add a vehicle; confirm it appears in the header chip.
2. Log 4 full fill-ups with backdated DATE & TIME so ranges differ, e.g.:
   - ~40 days ago — odometer `50000`, volume `40`, total `60`
   - ~35 days ago — `50600`, `45`, `70`
   - ~10 days ago — `51200`, `42`, `65`
   - ~2 days ago — `51800`, `43`, `62`

## Checklist

### 1. Metrics happy path (ALL)

- [ ] Metrics tab shows `LIFETIME COST` `€257.00`, `DISTANCE` `1,800 km`,
      `VOL (L)` `130.0`, `AVG L/100KM` `7.2`, `FILL-UPS` `4`.
- [ ] "Cost over time" card renders a polyline with 4 dots, `FIG.` label,
      y-axis money labels, first/last date on the x-axis.

### 2. Range switching

- [ ] Tap `30D`: card flips to `30D COST` `€127.00`, distance `1,200 km`,
      economy `7.1`, fill-ups `2`; chart shrinks to 2 points.
- [ ] `90D` / `YTD` behave consistently (YTD depends on today's date vs the
      seeded dates). `ALL` restores the lifetime numbers.

### 3. Empty + low-data states

- [ ] With no vehicles: Metrics shows the "No vehicles yet" card + `GO TO SETTINGS`.
- [ ] With a vehicle but no fill-ups: "No fill-ups yet" copy; range toggle still visible.
- [ ] Delete fill-ups (History → entry → Delete) until 1 remains: chart area is
      replaced by `NOT ENOUGH DATA` at the same height (no layout jump, no shimmer);
      summary card still shows the single fill-up's numbers. No crash at 0 or 1 entries.

### 4. Settings prefs drive units/currency (CES-65)

- [ ] Settings → Preferences → set distance `mi`, volume `gal`, currency `USD`.
- [ ] Log tab labels immediately read `ODOMETER (MI)` / `VOLUME (GAL)` / `TOTAL ($)`
      (no restart needed — pages watch the settings stream).
- [ ] Save a fill-up as `100` mi / `4` gal / `30.00`: History shows it as `$30.00`,
      and odometer/volume render in mi/gal.
- [ ] Existing EUR rows keep the `€` symbol in History (money stays in the currency
      it was logged in); only distance/volume flip to mi/gal.
- [ ] Metrics tiles switch to `VOL (GAL)` and `AVG MPG`.

### 5. Edit flow

- [ ] History → entry → Edit: fields are pre-filled in the current pref units;
      saving converts back correctly (spot-check odometer against the card display).

## Known limits (expected, not bugs)

- Mixed currencies in one range: summary leads with the preferred currency and lists
  others below; the chart draws one line per currency (deep fix is CES-51).
- Non-UTC IANA timezone in Settings: range boundaries approximate with the device's
  current UTC offset until a timezone database lands (UTC, the default, is exact).
- One chart only (cost over time); economy trend / category splits are Later per
  `docs/product/ux/DELIVERY_ACCEPTANCE.md`.
