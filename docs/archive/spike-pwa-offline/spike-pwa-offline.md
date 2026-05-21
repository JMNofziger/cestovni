# Spike: Flutter web PWA offline persistence (Safari iOS)

**Status:** **NO-GO** for full Flutter PWA offline on iOS Safari. T1 (offline cold start) failed twice on iPhone 13 mini / iOS 26.1 after two distinct root causes were patched (SW conflict, missing CanvasKit precache). Pivot path: **Option G (Hybrid)** in [`ios-offline-strategy.md`](ios-offline-strategy.md) — keep Flutter PWA as online cockpit, ship a vanilla-JS PWA-lite capture surface for offline fill-ups.
**Type:** Timeboxed spike (closed 2026-05-21)
**Linear:** CES-dist / PWA offline spike
**Spec:** [ADR 005](adr/005-distribution-channels.md) — Hybrid path is a new resolution outside ADR 005's original PWA-pass / App-Store-fallback binary (App Store ruled out by product 2026-05-21: no $99/yr recurring fee acceptable).
**Execution prompt:** [`../product/prompts/pwa-offline-spike.md`](../product/prompts/pwa-offline-spike.md)
**Preview URL:** https://spike-pwa-offline.cestovni-pwa.pages.dev

## Goal

Prove that an **installed PWA on Safari iOS 17+** can run Cestovni's core offline path: open without network, persist structured data in Drift on web, and survive app close/reopen — before committing M-dist iOS PWA build work.

## Out of scope for this spike

- Production Cloudflare deploy (preview URL is enough).
- Full photo TTL pipeline parity ([`photo-pipeline.md`](photo-pipeline.md)) — test and **scope**, do not fully implement.
- ZIP export ([`export-v1.md`](export-v1.md)) — not required for GO/NO-GO on logging.
- Glitchtip / telemetry wiring (M4).
- App Store or native iOS distribution.

## Known blockers (must be resolved in spike branch)

| # | Blocker | File(s) |
|---|---------|---------|
| 1 | `dart:io` + `NativeDatabase` breaks web compile | [`client/lib/db/app_database.dart`](../../client/lib/db/app_database.dart) |
| 2 | Native-only SQLite dep | [`client/pubspec.yaml`](../../client/pubspec.yaml) — add `drift_flutter` |
| 3 | No web scaffold | Run `flutter config --enable-web`; first `flutter build web` creates `client/web/` |
| 4 | OPFS requires COOP/COEP headers | Preview host `_headers` (Cloudflare Pages format) |

## Acceptance tests (manual on physical iPhone)

Run after **Add to Home Screen** (installed PWA, not Safari tab only).

| ID | Test | Pass criteria |
|----|------|---------------|
| T1 | Cold start offline | Airplane mode ON → launch from home screen → app shell loads (no white screen / endless spinner) |
| T2 | Persist fill-up | Online: create vehicle + one fill-up → close PWA → airplane mode ON → reopen → data still present |
| T3 | Theme toggle | Dark/light switch works offline after T2 |
| T4 | Camera capture (scope) | Capture one image via web camera API; record whether bytes can be stored in OPFS; note Safari version |
| T5 | Storage eviction (optional) | If time permits: document whether OPFS DB survives 24h background — observation only |

## Code changes (committed `spike/pwa-offline` — 3d5a798)

| Area | Change |
|------|--------|
| `client/pubspec.yaml` | Added `drift_flutter: ^0.2.8` |
| `client/lib/db/app_database.dart` | Replaced `dart:io` / `NativeDatabase` / `path_provider` with `driftDatabase()` from `drift_flutter`; web uses WASM + OPFS via `DriftWebOptions` |
| `client/web/` | Created by `flutter create . --platforms web`; updated `index.html` (branding, theme-color, apple-mobile-web-app-capable), `manifest.json` (Cestovni colours), added `_headers` (COOP/COEP/Service-Worker-Allowed) |
| `client/web/sqlite3.wasm` | Pre-built WASM module (sqlite3 2.9.4) — required for Drift on web |
| `client/web/drift_worker.js` | Drift web worker (drift 2.31.0) — required for shared-worker OPFS |

**flutter build web:** clean pass (zero errors)

**flutter test:** 110 / 110 pass (native VM)

**WASM assets:** `sqlite3.wasm` (714 KB) + `drift_worker.js` (347 KB) present in `build/web/`

## Spike outcomes

**Verdict:** **NO-GO** for full Flutter PWA offline on iOS Safari.

**Date / tester / iOS version:** 2026-05-21 / head-of-product / iPhone 13 mini, iOS 26.1

**T1–T5 results (run 1 — SW v6, pre CanvasKit precache):**

| ID | Pass/Fail | Notes |
|----|-----------|-------|
| T1 | **fail** | iOS network prompt + white screen on cold start (airplane mode) |
| T2 | not run | gated on T1 |
| T3 | not run | gated on T1 |
| T4 | not run | gated on T1 |
| T5 | not run | gated on T1 |

**T1–T5 results (run 2 — SW v7, CanvasKit precached, cache-first navigation):**

| ID | Pass/Fail | Notes |
|----|-----------|-------|
| T1 | **fail** | PWA reopens to white screen; does not resolve within 20 s offline. Two distinct root causes fixed already (SW conflict, missing CanvasKit) and still failing — diminishing-returns territory. |
| T2 | not run | gated on T1 |
| T3 | not run | gated on T1 |
| T4 | not run | gated on T1 |
| T5 | not run | gated on T1 |

### Run-1 root cause analysis

Inspecting `client/build/web/canvaskit/`: Flutter's renderer ships ~7 MB of WASM (`canvaskit.wasm`) + ~87 KB JS (`canvaskit.js`). These were **not** in `PRECACHE_URLS` in SW v6 — without them, Flutter cannot initialize the renderer offline, producing exactly the observed white-screen + network-required prompt.

### Fix candidate — SW v7 (deployed 2026-05-21)

Patched [`client/web/sw.js`](../../client/web/sw.js):

1. Added `/canvaskit/canvaskit.js` and `/canvaskit/canvaskit.wasm` to `PRECACHE_URLS`.
2. Bumped `CACHE_NAME` to `cestovni-v7` (forces clean activation, evicts v6).
3. Switched navigation handler to **cache-first** (was network-first): more robust against iOS standalone PWA quirks where `fetch()` on cold start may hang rather than reject cleanly.
4. Added explicit precache-miss logging (`[SW] MISS: <url>`) so future precache failures are visible in Web Inspector → SW console.
5. Replaced silent-undefined fallback with a 503 + readable text so cache-miss is no longer a white screen.

`client/web/flutter_service_worker.js` and `client/build/web/{sw,flutter_service_worker}.js` are byte-identical to `client/web/sw.js` (two-SW conflict still resolved by content equality, per run-0 work).

### Why NO-GO

Each run produced a different failure mode that, when fixed, exposed the next layer:

1. **Run 1 (SW v6):** `flutter_service_worker.js` (Flutter's no-op SW) raced our `sw.js` at the same `/` scope and intermittently won — caching nothing. Fixed by making the two files byte-identical so either winning produces correct behavior.
2. **Run 1 (SW v6, post-fix):** SW precache omitted `/canvaskit/canvaskit.{js,wasm}` (~7 MB renderer). Flutter web cannot render anything without these. Fixed in v7 by adding them and switching nav to cache-first.
3. **Run 2 (SW v7):** Still white-screens offline for ≥20 s. We have not pinpointed the next layer (could be: PWA storage-partition isolation, OPFS init blocking on missing async dependency, or another asset not precached). **Pattern is clear:** Flutter web on iOS Safari is layer after layer of fragility for a 5-field offline form. Stop investing here.

**Photo pipeline decision for iOS PWA:** `deferred` (capture surface no longer Flutter web on iOS — moves to PWA-lite per Option G; photo handling redesigned there).

**Blockers (in order found):**

1. Two-SW conflict at `/` scope (Flutter bootstrap + explicit `sw.js`) — **resolved.**
2. Missing CanvasKit assets in SW precache — **resolved.**
3. Unresolved residual failure at run-2 (white screen ≥ 20 s offline) — **not pursued** because:
   - $99/yr App Store path ruled out by product.
   - Continuing risks burning the remaining timebox without producing reliable offline UX for drivers.
   - Cheaper, lower-risk path exists (Option G).

**Recommended next engineering steps:**

1. Confirm Option G with product (in-flight at time of writing).
2. Scope Cursor execution prompt for **PWA-lite capture surface** at `/capture` — vanilla HTML + IndexedDB + tiny SW, no Flutter, no WASM. See [`ios-offline-strategy.md`](ios-offline-strategy.md) § Option G for the contract.
3. Keep Flutter PWA at `/` as **online-only** cockpit. Add a banner / link to `/capture` when offline is detected (or as a separate Add-to-Home-Screen target).
4. Note in ADR 005 (or addendum) that Hybrid is the third resolution path beyond the original PWA-pass / App-Store-fallback binary.

### Artifacts retained on `spike/pwa-offline`

- `client/web/sw.js` and `client/web/flutter_service_worker.js` (SW v7) — usable as the baseline SW for `/` (online cockpit) going into Option G; the precache list is correct for the Flutter shell, even though full-offline UX is NO-GO.
- `client/lib/db/app_database.dart` web compile path — still useful for the Flutter cockpit's local-cache layer when online; not the source of truth for offline capture under Option G.
- `client/web/_headers` (no COOP/COEP) — keep as-is; do not re-add COOP/COEP, they broke offline SW on Safari iOS 26.

## References

- Capability matrix: [ADR 005 § iOS PWA capability matrix](adr/005-distribution-channels.md)
- Android distribution (parallel, not blocked by this spike): ADR 005 § Android
