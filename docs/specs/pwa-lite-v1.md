# PWA-lite — iPhone offline fill-up capture (v1)

**Status:** Phase 0 — discovery
**ADR:** [005-addendum-pwa-lite-ios.md](adr/005-addendum-pwa-lite-ios.md)
**Discovery prompt:** [`../product/prompts/pwa-lite-discovery.md`](../product/prompts/pwa-lite-discovery.md)
**Spike archive:** [`../archive/spike-pwa-offline/`](../archive/spike-pwa-offline/)

## Goal

Replace pen-and-paper fill-up logging on iPhone. Drivers log gas fill-ups **fully offline** in remote locations; rows sync to the backend when online and appear in the Android native app.

## Platform split

| Platform | Surface | Stack | Offline |
|----------|---------|-------|---------|
| Android | Cestovni native | Flutter + Drift SQLite + outbox | Full app |
| iPhone | Cestovni (PWA-lite) | Vanilla HTML + JS + IndexedDB | Log + History |
| Backend | Source of truth | Per [ADR 001](adr/001-backend-api-boundary.md) | — |

**Not on iPhone:** Flutter web (spike NO-GO — see archive).

## UX (iPhone)

Two bottom tabs only. Visual language must match [`../product/ux/cestovni-styling.md`](../product/ux/cestovni-styling.md) (paper-ledger tokens, Fraunces/Inter/JetBrains Mono, ledger-card / ledger-tile / hairline components).

| Tab | Purpose |
|-----|---------|
| **Log** | Vehicle picker, odometer km, liters, date (default now), notes. Primary Save CTA. |
| **History** | Reverse-chrono fill-up list. Per-row sync pill: `PENDING` / `SYNCED`. |

**Sync status (minimal):** one mono micro-label in the header — `SYNCED`, `3 PENDING`, or `OFFLINE — 3 PENDING`. Tap for manual retry / detail sheet. No banners.

**Photos:** deferred after text-only capture is proven on physical iPhone.

## Code layout

```
client/web-lite/
  index.html      # shell + two tabs
  app.js          # IndexedDB queue, sync, routing
  styles.css      # OKLCH tokens from cestovni-styling.md
  sw.js           # tiny precache SW (~50 KB total app)
  manifest.json   # start_url: /
  fonts/          # self-hosted woff2 subsets
```

Deploy root: Cloudflare Pages (`cestovni-pwa.pages.dev`). Reuse icons from archived spike `client/web/icons/` when implementing.

## Sync contract

Align PWA-lite queue with Android `outbox` table — **one backend endpoint**, not a second iPhone-specific API. Exact shape TBC in Phase 0 discovery ([`pwa-lite-discovery.md`](../product/prompts/pwa-lite-discovery.md)).

Requirements:

- Client-generated row id + `Idempotency-Key` per row at save time (not at sync time).
- Idempotent server-side dedup (30-day window).
- Status flips `PENDING` → `SYNCED` per row after successful flush.

## Phases

| Phase | Deliverable | Gate |
|-------|-------------|------|
| 0 | Discovery report fills sections below in this doc | Open questions resolved |
| 1 + 2 | UI + IndexedDB + backend sync (ship together) | Offline capture → online sync → visible in Android |
| 3 | Receipt photos (optional) | After Phase 1+2 proven on iPhone |

## Phase 0 outputs (filled by discovery)

_To be completed by Cursor discovery pass — do not edit manually until discovery runs._

### Visual contract

_TBC_

### Log field map

_TBC_

### History list contract

_TBC_

### Data shapes (fill_ups, vehicles, outbox)

_TBC_

### Backend API

_TBC_

### Open questions

_TBC_
