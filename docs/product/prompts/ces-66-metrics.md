# Cursor execution prompt — CES-66 Metrics tab UI

> **Recommended next development step** after the 2026-07-22 architecture re-check.
>
> **Why this, not CES-63 / M3:** PWA-lite iPhone capability gap is an accepted Stage 1 tradeoff; CES-63 remaining work is mostly install-doc + product T1 against a tunnel (ops/product, thin coding value). Production backup (CES-42–45) stays on the spine but is not the immediate offline-app gap. Metrics is the missing piece of "**review fuel usage and vehicle history locally with zero network**" on the primary Android surface.

**Branch:** cut `cursor/ces-66-metrics-<suffix>` from `main` (use cloud-agent branch naming if applicable)
**Linear:** [CES-66](https://linear.app/personal-interests-llc/issue/CES-66) (High / `type:feature` / `effort:high`) — set In Progress when starting
**Spec:** `docs/specs/consumption-math.md` + `docs/product/ux/DATA_CONTRACTS.md` §Metrics + `docs/product/ux/cestovni-views.md` §Metrics
**UX refs:** `docs/product/ux/DELIVERY_ACCEPTANCE.md` §Metrics · `docs/product/ux/cestovni-styling.md` · screenshots `docs/product/ux/screenshots/dark-midnight/metrics.png` + `light-parchment/full-scroll/metrics-*.png`
**Delivery plan:** `docs/product/delivery-plan-v1.md` §Current focus → after A/B → **CES-66**

## Goal

Replace the Metrics tab stub with a working **offline** Metrics surface for the active vehicle:

1. Range filter: **30D / 90D / YTD / ALL**
2. Lifetime summary card: **distance + spend + average economy**
3. Canonical first chart: **Cost over time**
4. Low-data / empty placeholders (no skeleton shimmer)

Must work with **zero network**. Do not touch sync, PWA-lite, or server code.

## Prerequisite gap (do this first — ~small)

**CES-65 is Done on Linear but not in repo.** `client/lib/app/pages/log_page.dart` still hardcodes `currencyCode: 'EUR'` (and related unit display). Before or as Phase 0 of Metrics:

- Wire Log + History + Metrics display to `SettingsRepository` prefs (`preferredDistanceUnit`, `preferredVolumeUnit`, `currencyCode`, `timezone`).
- Pattern already exists in Settings UI / CES-57 — reuse, do not invent a second prefs path.
- Add/extend a widget test that asserts a non-default unit/currency appears in Log or History.
- If you fix prefs as part of this PR, mention CES-65 in the PR body and leave a Linear comment on CES-65 noting the repo gap was closed here (do **not** reopen unless product asks).

## Scope (in)

### Phase 1 — Aggregation layer (pure + repo)

1. Add a small metrics aggregation API (prefer pure functions over fat widgets):
   - Inputs: fill-ups for active vehicle (canonical INT64), settings prefs, selected range, timezone.
   - Outputs: lifetime totals (distance_m, spend_cents, economy average) + cost-over-time series for the selected range.
2. Reuse `client/lib/consumption/` for economy (`computeSegments` / `computeLifetime`). **Do not reimplement** segment math.
3. Range windowing:
   - Inclusive range boundaries built in `settings.timezone` per `DATA_CONTRACTS.md`.
   - `30D` / `90D` / `YTD` / `ALL` as defined in Metrics contract.
4. Cost-over-time series: bucket or point series of fill-up `total_price_cents` (or cumulative — pick one, document in code comment, match screenshot spirit). Multi-currency: if mixed currencies appear in range, show one series per currency **or** a clear single-currency limitation note (CES-51 owns deep fix — do not solve here).
5. Unit tests under `client/test/` for:
   - Range filtering boundaries
   - Lifetime totals
   - Economy uses full-fill segments only (partials excluded)
   - Low-data rule: fewer than 2 points → placeholder signal

### Phase 2 — Metrics UI

1. Replace stub in `client/lib/app/pages/metrics_page.dart`.
2. Wire to `ActiveVehicle` (same pattern as Log/History) + `FillUpsRepository` + `SettingsRepository`.
3. Must ship UI:
   - Range toggle (30D / 90D / YTD / ALL) — active = ink fill per full-views screenshot
   - Lifetime headline card (distance, spend, economy) using theme tokens (`LedgerCard`, Fraunces numerals, `labelMono`)
   - Cost-over-time chart card (title + `FIG.` label-mono + hairline)
   - Empty: no vehicle → same guided empty/CTA pattern as other tabs
   - Empty: vehicle but no fill-ups → lightweight copy
   - Low-data: placeholder that **preserves layout** (no shimmer)
4. Visual system: reuse `client/lib/app/theme/` — no new design language. Prefer existing `fl_chart` if already a dependency; otherwise a minimal custom painter / simple polyline is fine for MVP. Do **not** add a heavy charting SDK without need.
5. Widget tests:
   - At least one range switch updates visible aggregates
   - Empty / low-data states render
   - Happy path with seeded fill-ups shows lifetime + chart

### Phase 3 — Docs / board hygiene

1. Update `docs/product/delivery-plan-v1.md`: CES-66 → 🟩; refresh Current focus to **CES-67** next.
2. Update `docs/product/ux/cestovni-views.md` Metrics implementation note (no longer "stub").
3. Update `docs/product/ux/DELIVERY_ACCEPTANCE.md` header open-list (drop CES-65 if prefs fixed; mark Metrics shipped).
4. Close Linear CES-66 with a short status comment (what shipped / test counts / known limits).

## Scope (out)

- Extra charts from full-views mock (economy trend, price/gal, fuel vs maint donut, maint-by-category) — **Later** per DELIVERY_ACCEPTANCE. One chart only.
- Maintenance tab (**CES-67**)
- Photo pipeline (**CES-40**)
- Export (**CES-41**)
- Production server / CES-42–45
- PWA-lite / `client/web-lite/`
- Live multi-device sync / ZIP import (**CES-70**)

## Constraints

- Offline-first: Metrics reads local Drift only.
- Canonical storage stays INT64 µL / m / cents; convert only at display (`si-units.md` + `DATA_CONTRACTS.md` rounding).
- Economy: full-fill segments only; omit unknown/degenerate segments from averages (`consumption-math.md`).
- Soft-deleted fill-ups excluded.
- No new telemetry events unless already in `telemetry-events.v1.yaml` (prefer none this PR).
- Keep CI green: `cd client && flutter analyze && flutter test --no-pub` (run codegen first if schema touched — prefer **no** schema change).
- Do not edit the plan file under `/opt/cursor/artifacts/plans/`.

## Likely touchpoints

| Path | Role |
|------|------|
| `client/lib/app/pages/metrics_page.dart` | Replace stub |
| `client/lib/consumption/` | Read-only reuse for economy |
| `client/lib/db/repositories/fill_ups_repository.dart` | Source rows for active vehicle |
| `client/lib/db/repositories/settings_repository.dart` | Units / currency / timezone |
| `client/lib/app/active_vehicle.dart` | Vehicle context |
| `client/lib/app/pages/log_page.dart` / `history_page.dart` | Phase 0 prefs wiring if still hardcoded |
| `client/test/app/` + new metrics unit tests | Acceptance coverage |
| `docs/product/delivery-plan-v1.md` | RYG + Current focus |

## Acceptance criteria

- [ ] Metrics tab shows range filter + lifetime card + cost-over-time for active vehicle from local DB
- [ ] Range switches update aggregates/series
- [ ] Empty + low-data placeholders match UX rules (layout preserved, no shimmer)
- [ ] Display units/currency come from settings prefs (not hardcoded EUR/km/L)
- [ ] Economy math uses existing consumption module (golden behavior preserved)
- [ ] Widget + unit tests as above; `flutter analyze` + `flutter test --no-pub` green
- [ ] Delivery-plan / views notes updated; CES-66 closed Done with status comment

## Validation

```bash
cd client
# If you touched Drift schema (prefer not): dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --no-pub
```

Manual smoke (emulator/device):

1. Seed ≥3 full fill-ups across >30 days for one vehicle.
2. Open Metrics → ALL shows lifetime + chart.
3. Switch 30D → numbers/series shrink appropriately.
4. Delete down to 0–1 points → low-data / empty placeholders, no crash.
5. Change Settings units/currency → Metrics (and Log/History if Phase 0) reflect prefs without restart if streams already used; otherwise document refresh expectation.

## Status report (required at end of run)

Return a short status report with:

1. Files changed (bullet list)
2. Phase 0 prefs: fixed here or already present?
3. Aggregation approach (where range/lifetime/series live)
4. Chart approach (package or custom)
5. Test counts added + commands run
6. Known limitations (multi-currency, etc.)
7. PR URL + Linear CES-66 state

Tag: `CES-66 — Metrics tab UI`.
