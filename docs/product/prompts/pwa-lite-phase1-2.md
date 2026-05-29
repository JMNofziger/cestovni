# Cursor execution prompt — PWA-lite Phase 1+2 (iPhone)

> **Gate passed 2026-05-29** (Android E2E proof landed on `feat/m3-outbox-gate-slice`). **Phase 1+2 complete on `main`** (PR #3 `d10c115`, PR #4 `8c1f1a8`). **Next execution prompt:** [`pwa-lite-phase3-deploy.md`](pwa-lite-phase3-deploy.md).

**Branch:** merged to `main` — do not re-run Phase 1+2 unless regressing
**Spec:** [`docs/specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md) — Phase 0 discovery complete (**9 open questions**; defaults below unless product overrides)
**ADR:** [`docs/specs/adr/005-addendum-pwa-lite-ios.md`](../../specs/adr/005-addendum-pwa-lite-ios.md)

## Goal

Ship **Cestovni PWA-lite** for iPhone: offline Log + History with IndexedDB persistence, service worker offline shell, and sync to backend via `POST /api/v1/mutations`. Visual fidelity to paper-ledger design system. Deploy to Cloudflare Pages preview.

**Gate:** Physical iPhone smoke test — airplane mode → log fill-up → online → sync → row visible via `GET /api/v1/changes` (or dev stub).

## Product defaults (resolve open questions unless told otherwise)

Apply these defaults from discovery §8 — do **not** block on product if unspecified:

| # | Question | Default for implementation |
|---|----------|---------------------------|
| 1 | Log field scope | **Full DATA_CONTRACTS fields:** vehicle, datetime, odometer, volume, total price, currency (from settings), `is_full` toggle, notes. |
| 2 | Vehicle list | **Pull `vehicles` via `GET /changes` on online**; cache in IndexedDB; offline picker uses cache; zero vehicles → blocking empty state: "Add a vehicle in the Android app, then open Cestovni online once to sync." |
| 3 | Backend | **Add minimal dev sync stub** under `server/dev-sync-stub/` (Node or Cloudflare Worker) implementing `POST /api/v1/mutations` + `GET /api/v1/changes` + `GET /api/v1/settings` per `sync-protocol.md`. In-memory or SQLite OK for dev; not production. Real M3 backend (CES-43) replaces later. |
| 4 | Auth | **Dev bearer token:** store JWT in `localStorage` key `cestovni_token`; Settings tab (minimal) or URL `?token=` bootstrap for Phase 1+2; send `Authorization: Bearer …` on API calls. Document in README snippet. |
| 5 | History scope | **Local captures + pulled fill-ups** for active vehicle after online sync. Merge by `id`; show sync pill per row. |
| 6 | API prefix | **`/api/v1/mutations`**, **`/api/v1/changes`**, **`/api/v1/settings`** (align with self-host-runbook). |
| 7 | Advanced flags | **`missedBefore` + `odometerReset` behind "Advanced" disclosure**, default false, with one-line helper text each. |
| 8 | Settings bootstrap | **Hardcoded defaults until first pull:** `km`, `L`, `EUR`, `Europe/Prague`. Replace when `GET /changes?table=settings` returns a row. |
| 9 | Icons | **Copy from `git show spike/pwa-offline:client/web/icons/`** into `client/web-lite/icons/`; same for favicon if present on that branch. |

## Hard constraints

- **Vanilla HTML + CSS + JS only** in `client/web-lite/` — no Flutter, no WASM, no framework.
- **Two tabs:** Log + History. Header: brand, date subtitle, sync micro-label, theme toggle. No Metrics / Maint / Settings nav (token entry can live in header long-press or minimal modal).
- **Theming:** port tokens from discovery §1 — OKLCH CSS vars, Fraunces/Inter/JetBrains Mono self-hosted woff2, `.ledger-card`, `.ledger-tile`, `.label-mono`, `.btn-primary`.
- **Sync status minimal:** header micro-label (`SYNCED` / `N PENDING` / `OFFLINE — N PENDING`); row pills in History; tap header → retry sheet (no toast spam).
- **Canonical storage:** integers only (`odometer_m`, `volume_uL`, `total_price_cents`); convert at save/display per `si-units.md`.
- **Validation:** port rules from `client/lib/consumption/validation.dart#validateInsert` to plain JS.
- **Outbox:** enqueue on save per `sync-protocol.md`; `mutation_id` at enqueue time; reuse on retry.
- **No COOP/COEP headers** in `_headers`.
- **Do not touch** `client/lib/` except if adding a one-line comment somewhere is truly needed (prefer zero Dart changes).
- **Do not re-add** `client/web/` Flutter artifacts.

## File layout (create)

```
client/web-lite/
  index.html
  styles.css
  app.js              # UI, routing, validation, sync orchestration
  idb.js              # IndexedDB schema + CRUD (optional split)
  sw.js
  manifest.json
  _headers
  icons/              # from spike branch
  fonts/              # Fraunces 600, Inter 400/600, JetBrains Mono 400/500 woff2
server/dev-sync-stub/
  README.md           # how to run locally + env vars
  ...                 # minimal POST /api/v1/mutations + GET /api/v1/changes
docs/specs/pwa-lite-v1.md   # update Status → Phase 1+2 in progress when starting
```

Deploy: `wrangler pages deploy client/web-lite --project-name cestovni-pwa --branch main` (or preview branch).

---

## Phase 1 — Offline shell + Log + History + IndexedDB

**Deliver:** Working PWA offline on iPhone without network after first precache.

### Tasks

1. **Scaffold** `client/web-lite/` with HTML shell: header, tab bar (Log | History), `#app` content region, safe-area padding.
2. **CSS** — full visual contract from `pwa-lite-v1.md` §1; dark default; theme toggle flips `[data-theme]`; max-width 672px centered column.
3. **Fonts** — subset and self-host woff2 under `fonts/`; `font-display: swap`.
4. **IndexedDB schema** (version 1):
   - `vehicles` — key `id`
   - `fill_ups` — key `id`, index `vehicle_id`, `filled_at`
   - `outbox` — auto-increment `id`, index `row_id`
   - `settings` — key `id` (singleton)
   - `sync_meta` — key `table`, value `{ last_since }`
5. **Log tab** — form per §2 field map; Save writes `fill_ups` + `outbox` in one transaction; inline validation errors.
6. **History tab** — list for active vehicle; ordering §3; empty state; row pills default `PENDING`.
7. **Vehicle selector** in header — dropdown from cached `vehicles`; session-persist selected id in `sessionStorage`.
8. **Service worker** — precache app shell + fonts + icons; cache-first for same-origin GET; navigation fallback to `/`.
9. **manifest.json** + `_headers` per §6.
10. **Copy icons** from spike branch.

### Phase 1 status report (return when done)

```markdown
## Phase 1 status
- Files created: [list]
- IndexedDB stores: [list]
- LOC estimate: [n]
- Deploy URL: [url]
- iPhone T1 (offline cold start + log + history): pass/fail + notes
- Deviations from spec: [none | list]
- Blockers for Phase 2: [list]
```

### Phase 1 status — filled (2026-05-29, `feat/pwa-lite-phase1`)

```markdown
## Phase 1 status
- Files created: client/web-lite/{index.html, styles.css, app.js, idb.js, sw.js,
  manifest.json, _headers}, client/web-lite/icons/* (4 PNGs from spike/pwa-offline),
  client/web-lite/fonts/README.md
- IndexedDB stores: vehicles, fill_ups (idx vehicle_id, filled_at), outbox
  (autoinc id, idx row_id), settings (singleton), sync_meta
- LOC estimate: ~720 (app.js ~390, styles.css ~290, idb.js ~125, index.html ~50, sw.js ~55)
- Deploy URL: not deployed (Cloudflare Pages deferred; serve locally with
  `python3 -m http.server` from client/web-lite/)
- iPhone T1 (offline cold start + log + history): not run on device; desktop
  smoke pass (SW registers, offline reload serves shell, save → PENDING row)
- Deviations from spec:
  - Self-hosted woff2 fonts deferred — CSS uses spec fallback stacks (see fonts/README.md)
  - Dev-only `?devseed=1` URL param seeds one demo vehicle (no Phase 2 pull yet);
    without it, zero vehicles correctly shows the blocking empty state
  - History sync pill stub: PENDING when outbox row exists, else SYNCED (no real
    flush in Phase 1); header label shows OFFLINE / N PENDING only
- Blockers for Phase 2: none — outbox rows already carry the frozen Android
  envelope/payload, ready for POST /api/v1/mutations flush against dev-sync-stub
```

---

## Phase 2 — Sync client + dev backend stub

**Deliver:** Offline capture → online flush → row queryable via API (dev stub); Android-visible once M3 real backend exists.

### Tasks

1. **Sync pull (online bootstrap):**
   - `GET /api/v1/changes?table=settings&since=0`
   - `GET /api/v1/changes?table=vehicles&since=0`
   - `GET /api/v1/changes?table=fill_ups&since=0` (for active vehicle or all)
   - Upsert into IndexedDB; update `sync_meta`.
2. **Sync push:**
   - Drain `outbox` oldest-first; batch ≤100 mutations.
   - `POST /api/v1/mutations` with bearer token.
   - On `applied|duplicate`: mark row SYNCED, delete outbox entry, hydrate `row_version` if returned.
   - On retriable error: increment `attempts`, backoff per sync-protocol (1s→30s cap).
   - On non-retriable: mark row ERROR pill.
3. **Triggers:** `online` event, app foreground, manual retry from header tap, after Save if online.
4. **Header sync label** — compute pending count from outbox length; update on every drain attempt.
5. **Dev sync stub** (`server/dev-sync-stub/`):
   - Accept mutations per `sync-protocol.md` request/response shapes.
   - Store rows in memory or SQLite file.
   - Assign monotonic `row_version`.
   - Dedupe by `mutation_id`.
   - CORS enabled for Pages preview origin.
   - README with `curl` examples.
6. **Wire preview:** document how Pages preview calls stub (separate Worker URL or local tunnel); env var `CESTOVNI_API_BASE` in `app.js`.
7. **Contract test** (optional but preferred): one Node test posting a fill-up mutation and reading it back via `GET /changes`.

### Phase 2 status report (return when done)

```markdown
## Phase 2 status
- Sync client: [done | partial]
- Dev stub path: [path]
- E2E curl proof: [paste mutation_id + row_id]
- iPhone round-trip: offline save → online sync → History shows SYNCED: pass/fail
- Files changed: [list]
- Deviations: [list]
- Remaining for production (CES-43): [list]
```

### Phase 2 status — filled (2026-05-29, `feat/pwa-lite-phase2`)

```markdown
## Phase 2 status
- Sync client: done — client/web-lite/sync.js (push drain ≤100 oldest-first +
  retry matrix/backoff 1s→30s, pull bootstrap settings/vehicles/fill_ups,
  config CESTOVNI_API_BASE + localStorage cestovni_token + ?token=). Wired in
  app.js: triggers (online, foreground/visibilitychange, load, after-save,
  header-tap manual retry), header label SYNCED / N PENDING / OFFLINE — N
  PENDING, History pills PENDING/SYNCED/ERROR.
- Dev stub path: server/dev-sync-stub/server.js — added permissive CORS +
  OPTIONS preflight (local + Pages preview origins); endpoints unchanged.
- E2E curl proof: contract test (server/dev-sync-stub/contract.test.js) —
  mutation_id=3b7cea29-7e59-4d11-8842-fe563149b9bf
  row_id=2ed68a63-2347-4813-9d6e-f903426fa705 row_version=1 (applied → duplicate).
- iPhone round-trip: not run on device (product validates T1 separately).
  Desktop browser E2E PASS against running stub: save online → outbox drained,
  fill_ups.row_version hydrated, label SYNCED; stub-down save → row retained
  PENDING with attempts=2 + last_error="transport: Failed to fetch" (retriable);
  stub-up + header-tap retry → outbox drained → History pills flip SYNCED.
- Files changed: client/web-lite/{sync.js (new), app.js, idb.js, sw.js (v2
  precache + sync.js), styles.css (.pill-bad)}, server/dev-sync-stub/{server.js,
  contract.test.js (new)}, docs/specs/pwa-lite-v1.md, this file.
- Deviations: getToken() falls back to the dev bearer so a clean checkout
  flushes against the stub without manual token setup; real deployments set
  localStorage / ?token=. ERROR pill is minimal (dead-letter UX is CES-45).
- Remaining for production (CES-43): real JWT/OIDC + per-user RLS, Postgres
  persistence, 429 Retry-After parsing, dead-letter retry sheet (CES-45),
  Cloudflare Pages deploy + CESTOVNI_API_BASE wiring to the real backend.
```

---

## Testing checklist

- [ ] SW precache ≤200 KB excluding fonts; offline cold start <3s on iPhone
- [ ] Save fill-up offline → appears in History as PENDING
- [ ] Airplane off → Log + History still work
- [ ] Online → pending count drains; pills flip to SYNCED
- [ ] Invalid odometer regression rejected inline
- [ ] Theme toggle works offline
- [ ] Zero vehicles shows blocking empty state (not a crash)
- [ ] `flutter test` still 110/110 (no Dart regressions)

## Commit guidance

- One commit per phase minimum; message prefix `feat(pwa-lite):`.
- No Cursor attribution trailers.
- Do not commit `.wrangler/` cache.

## References

- Discovery: `docs/specs/pwa-lite-v1.md`
- Sync protocol: `docs/specs/sync-protocol.md`
- Data contracts: `docs/product/ux/DATA_CONTRACTS.md`
- SI units: `docs/specs/si-units.md`
- Validation reference: `client/lib/consumption/validation.dart`
- Fill-up repo reference: `client/lib/db/repositories/fill_ups_repository.dart`

Tag: `Phase 1+2 — PWA-lite iPhone implementation`.
