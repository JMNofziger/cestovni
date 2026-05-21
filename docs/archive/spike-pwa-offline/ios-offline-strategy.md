# iOS offline strategy — options beyond Flutter PWA

**Status:** **Decision in progress** — spike PWA T1 failed twice (run 1 + run 2) on iPhone 13 mini / iOS 26.1; declared NO-GO for full Flutter PWA offline. Product has ruled out paid App Store distribution (no $99/yr recurring fee).
**Date:** 2026-05-21
**Related:** [ADR 005 § iOS PWA capability matrix](adr/005-distribution-channels.md), [spike-pwa-offline.md](spike-pwa-offline.md)

## Hard constraints (fixed by product 2026-05-21)

1. **No paid platform fees** — Apple Developer Program ($99/yr) and any equivalent recurring store fees are out. This rules out **Option B** (TestFlight / App Store) and **Option F** (Capacitor → TestFlight). Documented below for completeness but not selectable.
2. **Offline iPhone fill-up capture is P0** — pen-and-paper is the current fallback; product accepts no degraded experience that keeps pen-and-paper as the de-facto path.
3. **Reuse existing Flutter investment where possible** — do not build a second full client; the offline surface can be a thin, separate capture path.

## Problem we are solving

Drivers log gas fill-ups in **remote locations with no cellular signal** (gas stations on backroads, border crossings, mountain passes). Today they use **pen and paper in the car** and re-enter later — error-prone, often skipped, no photo of receipt.

The fill-up entry path must work **fully offline** on **iPhone**. Online sync can come later. The dataset is tiny: vehicle picker (≤5 vehicles), liters, odometer km, date, optional receipt photo, optional notes.

## Why we are at this decision point

- Flutter web PWA spike failed T1 (offline cold start) on iOS 26.1 in **two** consecutive runs after two distinct root causes were patched (SW conflict, missing CanvasKit precache). Run 2 still produces a ≥ 20 s offline white screen.
- iOS PWAs have multiple compounding fragilities:
  - Storage partition isolation (Safari tab ≠ installed PWA, since iOS 16.4)
  - 7-day inactivity eviction of OPFS / IndexedDB / Cache Storage
  - WKWebView-only engine — no escape hatch from Safari quirks
  - ~3 MB JS + 7 MB CanvasKit WASM cold start (heavy for a fill-up form)
- ADR 005 pre-committed a revisit gate: **"PWA spike is NO-GO and product requires full native parity on iPhone."** Original suggested action was to schedule App Store work, but product has now ruled out the $99/yr fee — so we need a **third resolution path** beyond the original binary.

## Options matrix


| #   | Option                                                                        | Offline reliability on iOS                                  | Build effort                                           | Recurring cost                       | Distribution friction                             | Reuse of current Flutter work |
| --- | ----------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------ | ------------------------------------------------- | ----------------------------- |
| A   | **Continue Flutter PWA spike** (current path)                                 | Low–medium (best-effort, multi-quirk)                       | ~2–5 more days to retest T1–T4                         | $0                                   | Add to Home Screen (good)                         | Full                          |
| B   | **Flutter native iOS via TestFlight**                                         | High                                                        | ~3–5 days to wire ad-hoc + TestFlight build            | **$99/yr** Apple Dev + 1h/yr renewal | TestFlight invite link (medium); 90-day re-invite | Full                          |
| C   | **Pure HTML/JS fill-up PWA-lite** (separate page, no Flutter)                 | High (≤50 KB, no WASM, IndexedDB only)                      | ~2–3 days to build minimal form + sync                 | $0                                   | Add to Home Screen (good)                         | Backend API only              |
| D   | **iOS Shortcut** that writes to a local file / Apple Notes                    | Very high (native)                                          | ~½ day to build template + parser                      | $0                                   | Send shortcut link (low)                          | Backend parser only           |
| E   | **Apple Notes / Numbers template** (no code)                                  | Very high (native)                                          | ½ day to design template + import script               | $0                                   | Share link (very low)                             | Backend parser only           |
| F   | **Flutter web wrapped in Capacitor + TestFlight**                             | Medium (still WKWebView, but native shell controls storage) | ~3–4 days                                              | **$99/yr**                           | TestFlight                                        | Full                          |
| G   | **Hybrid: keep Flutter PWA for online + Option C/D for offline-capture only** | High for capture; medium for full app                       | ~2 days (C as offline form, Flutter as online cockpit) | $0                                   | One Safari URL → both                             | Full + small extra            |


## Recommended decision tree

```
Is fully-offline iPhone capture P0 for Stage 1?
├── YES → go to (1)
└── NO  → ship Android native + iOS-online-only Flutter PWA; revisit Q3
(1) Are we willing to pay $99/yr Apple Dev fee?
    ├── YES → Option B (Flutter native iOS via TestFlight). Highest quality,
    │         lowest engineering risk, reuses Flutter codebase. Recommended.
    └── NO  → Option G (Hybrid). Build Option C — a 50 KB vanilla-JS
              offline-capture form — alongside the Flutter PWA. Capture works
              offline reliably; full cockpit (history, exports, settings) lives
              in Flutter PWA when online. Pen-and-paper replaced. Recommended
              if Apple fee is a hard no.
```

## Option deep-dive

### A — Continue Flutter PWA spike

- **Pros:** $0 recurring, single codebase, instant install (no app store).
- **Cons:** Compounding iOS Safari fragilities; each fix uncovers the next. Heavy WASM + JS cold start ill-suited to a remote-area cold launch on a battery-low phone with intermittent signal at install time.
- **Stop condition:** if SW v7 + reinstall still fails T1, do not invest more in this path. Decide between B and G.

### B — Flutter native iOS via TestFlight (Apple $99/yr)

- **Pros:** Drift native SQLite (already working — 110/110 tests pass); full offline; same Dart codebase; no Safari quirks; TestFlight invite is one tap for users.
- **Cons:** $99/yr fee; TestFlight invites expire every 90 days (must re-add); 1–3 day Apple review for TestFlight initial submission (subsequent builds within minutes).
- **What's required:** Apple Developer Program enrollment, App Store Connect record, internal/external tester groups, signing certs. ADR 005 already paused weekly iOS CI to save fees — re-enable on Option B selection.
- **Stage cost over 3 years:** ~$300 vs $0. Acceptable if drives even 1 hour/year of pen-and-paper savings per driver across ~50 drivers.

### C — Pure HTML/JS PWA-lite (no Flutter)

- **Pros:** ~50 KB total payload (vs ~10 MB Flutter web). Vanilla `<form>` + `IndexedDB.put()` + a 30-line service worker. Far less to go wrong on iOS Safari. Same Cloudflare Pages distribution. $0.
- **Cons:** Second client surface to maintain alongside Flutter web/native. No reuse of Drift schema or Flutter UI components — but the offline-capture surface is intentionally minimal (5 fields).
- **Sync contract:** new endpoint on backend API per [ADR 001](adr/001-backend-api-boundary.md): `POST /v1/fillups/queue` accepts an array of offline-captured rows + `Idempotency-Key`; backend merges into canonical store.
- **What ships:** `[client/web-capture/index.html](../../client/web-capture/)` — single-page form with offline indicator, "queued / synced" badge per row, manual sync button.

### D — iOS Shortcut

- **Pros:** Zero distribution. Works in airplane mode. Uses native iOS share sheet. ~½ day of work to design + parser.
- **Cons:** Discoverability is poor (users must install a Shortcut). No photo capture inside Shortcuts is awkward. Re-entry into Cestovni still needed for review.
- **Use as:** **emergency fallback only** — ship as a backup capture method alongside the main app, not the primary surface.

### E — Apple Notes / Numbers template

- **Pros:** Zero engineering on the capture side. Users already trust Notes; works offline by default; iCloud syncs when online.
- **Cons:** No structured parsing without effort on backend (we'd need to parse a template). Photos in Notes don't carry receipt-photo metadata cleanly. Cannot enforce schema (drivers will free-text).
- **Use as:** **interim** while Option B or G is built — better than pen-and-paper today; replace within 2 sprints.

### F — Capacitor wrapper

- **Pros:** Reuses Flutter web build; native shell can pin SW storage and force a steady offline cache.
- **Cons:** Still WKWebView under the hood — most Safari offline quirks still apply. **Also needs $99/yr** Apple Dev. Adds a build pipeline (`npx cap` etc.) for marginal benefit over Option B.
- **Recommend against:** if we're paying $99/yr anyway, ship Option B with proper native Flutter — better UX, simpler stack.

### G — Hybrid: Flutter PWA online + PWA-lite offline-capture

- **Pros:** Keeps Stage 1's $0-recurring promise; gives drivers a reliable offline button on iPhone today; full app available online from same URL.
- **Cons:** Two client surfaces; sync merge logic + idempotency contract must be tight.
- **UX flow:**
  1. Driver opens `cestovni-pwa.pages.dev` in Safari (or installed PWA).
  2. Online: full Flutter app loads — history, exports, settings.
  3. Offline (Flutter shell unavailable): driver taps the installed home-screen icon for the **"Quick Fill-Up"** lite PWA at `/capture` — single form, IndexedDB queue, "X queued" badge.
  4. When online next, queue auto-syncs to backend via `POST /v1/fillups/queue`; rows appear in the Flutter cockpit history.

## Selected option: **H — iPhone PWA-lite ONLY (no Flutter web on iOS)**

Refined from Option G after the head-of-product confirmed:

- iPhone users only need **two screens**: log a fill-up + view history with sync status.
- No need to preserve Flutter web on iOS — it adds zero value once it's not the offline surface.
- Visual continuity across platforms is critical — the iPhone PWA-lite must match the existing Flutter app's **paper-ledger** visual language ([`../product/ux/cestovni-styling.md`](../product/ux/cestovni-styling.md)) so drivers don't perceive UX drift between Android and iPhone.

| Platform | Surface | Stack | Offline reach |
|---|---|---|---|
| **Android** | Cestovni native (existing) | Flutter + Drift SQLite + outbox | Full app offline |
| **iPhone** | **Cestovni Lite** at `/` (root of `cestovni-pwa.pages.dev`) | Vanilla HTML + JS + IndexedDB | Log + History offline; sync when online |
| **Desktop browser (optional)** | Power-user cockpit | Server-rendered HTML or Flutter web (deferred — only if a driver actually asks for it) | Online only |
| **Backend** | Source of truth | Per ADR 001 | — |

Why this wins under the constraints + new UX requirements:

1. Costs **$0 recurring** (honors ADR 005's cost floor).
2. **Highest possible offline reliability** on iOS Safari — vanilla HTML + IndexedDB is the most mature offline primitive, with ~200× less surface area to fail than Flutter web + WASM + OPFS.
3. **Single iPhone surface**, no dual-PWA mental model for drivers. One tap on the home-screen icon = the app.
4. **Visual continuity preserved** by porting the existing OKLCH design tokens + Fraunces/Inter/JetBrains-Mono typography stack into CSS custom properties. Same paper-ledger feel; same ledger-card / ledger-tile / hairline-divider components in HTML + CSS.
5. **Reversible:** if PWA-lite proves fragile in production, Option E (Notes template, 1 day) is a documented bridge, and ADR 005 can be re-opened to revisit the App Store decision.

### iPhone UX (Option H)

Bottom-tab nav, two tabs only (matches the reduced-nav-items decision):

| Tab | Purpose | Offline |
|---|---|---|
| **Log** | One-screen fill-up entry: vehicle picker → odometer km → liters → date (defaults to now) → notes. Big "Save" CTA (primary ink-fill, mono uppercase per § 7 of styling spec). | Fully offline — writes to IndexedDB. |
| **History** | Reverse-chrono list of fill-ups (ledger-tile rows). Each row shows date, vehicle, liters, km, plus a **minimal sync status indicator** — a small mono pill (`PENDING` / `SYNCED`) or icon in the row's meta strip. | Fully offline — reads from IndexedDB. |

Global sync status — clear but minimal — lives as a **single mono micro-label** in the app's header strip (top-right): `SYNCED` (no pending), `3 PENDING` (count > 0), or `OFFLINE — 3 PENDING` (no network + count > 0). No banners, no toasts on every change. Tap the indicator to open a one-page sync-detail / manual-retry sheet for diagnostics.

### Backend contract

`POST /v1/fillups/queue` per [ADR 001 § backend API boundary](adr/001-backend-api-boundary.md). The Flutter app already has an `outbox` table pattern — the PWA-lite sync queue must align with it so the backend endpoint serves both clients (no second endpoint for iPhone). Discovery prompt below confirms / extends this.

- Headers: `Idempotency-Key: <uuid-per-row>` (server-side dedup window: 30 days).
- Body: same shape Android's outbox already produces (TBC in discovery).
- Idempotent. Safe to retry indefinitely.

### Files Option H adds (high level — execution prompt will specify)

- `client/web-lite/index.html` — single-page app shell, two tabs (Log + History).
- `client/web-lite/app.js` — IndexedDB queue, sync loop, offline detection, tab routing.
- `client/web-lite/styles.css` — visual port of [`cestovni-styling.md`](../product/ux/cestovni-styling.md) tokens (OKLCH light + dark via `prefers-color-scheme` + manual toggle).
- `client/web-lite/sw.js` — tiny precache + cache-first SW (drop the Flutter SW v7; replace with a much smaller one scoped to `/`).
- `client/web-lite/manifest.json` — `start_url: /`, branded as "Cestovni" (not a separate "Lite" brand from the user's perspective).
- `client/web-lite/fonts/` — self-hosted Fraunces 600, Inter 400/600, JetBrains Mono 400/600 woff2 subsets (~120 KB total, font-display: swap so first paint never blocks).
- Backend route handler for `POST /v1/fillups/queue` if the Android `outbox` doesn't already use a compatible endpoint (TBC in discovery).
- `docs/specs/pwa-lite-v1.md` — implementation spec (created alongside execution prompt).

The existing `client/web/` and `client/build/web/` Flutter PWA assets remain on the `spike/pwa-offline` branch for now but should be **removed in the same PR that ships PWA-lite at `/`** so there's no confusion about which surface is canonical.

### Effort and risk

- **Total effort:** ~2–3 days — 1 frontend day (HTML shell + theme port + IndexedDB + SW), 1 backend day (sync endpoint alignment with outbox + tests), ½ day physical-iPhone smoke test + iteration.
- **Primary risk:** receipt-photo capture-and-store on iOS Safari is its own iceberg (HEIC encoding, blob size limits, IndexedDB blob quirks). **Mitigation:** ship Phase 1 text-only (replaces pen-and-paper today); add photos in Phase 2 once the capture loop is proven on physical iPhone.
- **Secondary risk:** 7-day iOS storage eviction on idle PWAs. **Mitigation:** backend is canonical; show a `LAST SYNCED Xd AGO` mono micro-label when `> 5 days`; encourage drivers to find signal at least weekly.
- **Tertiary risk:** font payload bloat. **Mitigation:** subset fonts to Latin + the few special chars we use; total under 150 KB; `font-display: swap` so no blocking.

## Rejected options recap (recorded for ADR 005 revisit history)

- **A (continue Flutter PWA full-offline):** NO-GO per spike runs 1 + 2.
- **B (TestFlight / App Store):** ruled out by recurring-fee constraint.
- **F (Capacitor + TestFlight):** ruled out by same fee constraint; would still be WKWebView under the hood (most Safari quirks unchanged).
- **G (Hybrid: Flutter PWA cockpit + PWA-lite capture):** superseded by H — keeping Flutter web on iOS adds complexity without value once Cestovni Lite has both Log and History.
- **D (iOS Shortcut), E (Notes template):** retained as **emergency fallbacks** if Option H implementation slips — viable but inferior UX vs the dedicated PWA-lite surface.

## Phase plan for Option H

| Phase | Deliverable | Effort | Gate |
|---|---|---|---|
| 0 — Discovery | Cursor reads existing theme tokens, Log/History page layout, fill_ups + vehicles + outbox schemas, backend API client patterns, returns a structured report. Output: `docs/specs/pwa-lite-v1.md` skeleton + open questions for product. | ~½ day Cursor + ½ hr product review | All open questions resolved with product |
| 1 — Capture + History UI + local-only persistence | `client/web-lite/{index,app,sw,styles,manifest}.{html,js,css,json}` + fonts; Log + History tabs functional with IndexedDB persistence; sync status shows `OFFLINE` always (no backend yet). Smoke-test on physical iPhone. | ~1 day | T1 (offline cold start + log + history) passes on iPhone 13 mini |
| 2 — Backend sync endpoint + queue flush | `POST /v1/fillups/queue` aligns with Android outbox; PWA-lite background-syncs on online + manual retry; status flips `PENDING` → `SYNCED` per row. | ~1 day | Round-trip (capture offline → sync online → row appears in Android cockpit) passes |
| 3 — (Optional) Receipt photo capture | Camera input, blob compression, IndexedDB photo store, sync as multipart or `photo_blob_id`. | ~1–2 days | Deferred — schedule after Phase 2 ships |
| 4 — Cleanup | Delete `client/web/` Flutter web assets; update ADR 005 with H addendum; remove paused iOS CI references that no longer apply. | ~2 hr | PR review |

## What I need next from product

- [x] **Option H confirmed** with theming-fidelity + reduced-nav + minimal-sync-status constraints.
- [x] **Phases 1 + 2 ship together** (one ~2–3 day push, full offline-capture → online-sync round-trip from day one). Avoids an interim "looks-working-but-data-stays-on-phone" beta state. Phase 0 (discovery) runs first as a read-only Cursor pass to ground the execution prompt.
- [ ] Hand the Phase 0 discovery prompt at [`../product/prompts/pwa-lite-discovery.md`](../product/prompts/pwa-lite-discovery.md) to a fresh Cursor session; route the resulting `docs/specs/pwa-lite-v1.md` back to product for open-question resolution.

## References

- [ADR 005 § revisit gates](adr/005-distribution-channels.md) — "PWA spike NO-GO" trigger satisfied; App-Store branch of the gate explicitly rejected by product. Hybrid is a new resolution that should be captured as an ADR 005 addendum once Option G ships.
- [spike-pwa-offline.md](spike-pwa-offline.md) — closed spike with NO-GO verdict and run-1 + run-2 results.
- [ADR 001 § backend API boundary](adr/001-backend-api-boundary.md) — `Idempotency-Key` contract any offline-capture surface must conform to.

