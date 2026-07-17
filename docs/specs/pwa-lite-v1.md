# PWA-lite — iPhone offline fill-up capture (v1)

**Status:** **Phase 1+2 complete on `main`** (2026-05-29) — PR #3 (`d10c115`) offline shell; PR #4 (`8c1f1a8`) sync push/pull vs `server/dev-sync-stub/`. **Next:** Cloudflare Pages preview deploy + iPhone install doc ([`pwa-lite-phase3-deploy.md`](../product/prompts/pwa-lite-phase3-deploy.md)); production API remains CES-43.
**ADR:** [005-addendum-pwa-lite-ios.md](adr/005-addendum-pwa-lite-ios.md)
**Discovery prompt:** [`../product/prompts/pwa-lite-discovery.md`](../product/prompts/pwa-lite-discovery.md) (complete)
**Execution prompt:** [`../product/prompts/pwa-lite-phase1-2.md`](../product/prompts/pwa-lite-phase1-2.md) (Phase 1+2 — **complete**); [`../product/prompts/pwa-lite-phase3-deploy.md`](../product/prompts/pwa-lite-phase3-deploy.md) (deploy — **active**)
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

---

## 1. Visual contract (CSS-ready)

Source: [`../product/ux/cestovni-styling.md`](../product/ux/cestovni-styling.md), `client/lib/app/theme/cestovni_{tokens,typography,primitives,theme}.dart`.

### CSS custom properties

Use `[data-theme="light"]` / `[data-theme="dark"]` on `<html>`. Default **dark** (styling spec §5).

| Token | Light OKLCH | Dark OKLCH | Use |
|-------|-------------|------------|-----|
| `--c-paper` | `oklch(0.96 0.018 85)` | `oklch(0.16 0.01 60)` | Screen background |
| `--c-paper-deep` | `oklch(0.92 0.025 85)` | `oklch(0.22 0.012 60)` | Tiles, inset blocks |
| `--c-card` | `oklch(0.98 0.012 85)` | `oklch(0.2 0.012 60)` | Primary card fill |
| `--c-ink` | `oklch(0.18 0.01 60)` | `oklch(0.94 0.015 85)` | Text, borders, primary fills |
| `--c-rule` | `oklch(0.35 0.015 60)` | `oklch(0.55 0.015 60)` | Hairline dividers |
| `--c-muted` | `oklch(0.42 0.015 60)` | `oklch(0.7 0.015 60)` | Mono micro-labels |
| `--c-accent` | `oklch(0.65 0.18 40)` | `oklch(0.7 0.18 40)` | Highlights |
| `--c-good` | `oklch(0.55 0.13 145)` | `oklch(0.55 0.13 145)` | Synced / positive |
| `--c-warn` | `oklch(0.7 0.16 75)` | `oklch(0.7 0.16 75)` | Pending / partial |
| `--c-bad` | `oklch(0.5 0.21 27)` | `oklch(0.6 0.21 27)` | Errors / destructive |
| `--c-chart-1` … `--c-chart-5` | light §4 chart table | dark §5 chart table | Deferred (Phase 3+) |

Layout metrics (also as CSS vars): `--radius-base: 6px`, `--hairline: 1px`, `--shadow-offset: 3px`, `--tile-pad: 12px`, `--card-pad: 24px`, `--page-pad: 16px`, `--content-max: 672px`, `--section-gap: 24px`.

### Typography

| Role | Family | Weights needed (Log + History) | Fallback |
|------|--------|--------------------------------|----------|
| Headlines | Fraunces | **600** only | Playfair Display, Georgia, serif |
| Body / labels | Inter | **400**, **600** | system-ui, sans-serif |
| Mono / pills / buttons / numeric fields | JetBrains Mono | **400**, **500** | IBM Plex Mono, monospace |

Self-host woff2 Latin subsets: estimate **~120–150 KB** total with `font-display: swap`. Flutter uses `google_fonts` at runtime; PWA-lite must bundle files under `client/web-lite/fonts/`.

`label-mono`: 11px, weight 500, letter-spacing `0.12em`, uppercase at render time, color `--c-muted`.

### Component CSS recipes

```css
.ledger-card {
  background: var(--c-card);
  border: var(--hairline) solid var(--c-ink);
  border-radius: var(--radius-base);
  box-shadow: var(--shadow-offset) var(--shadow-offset) 0 0 var(--c-ink);
  padding: var(--card-pad);
}
.ledger-tile {
  background: var(--c-paper-deep);
  border: var(--hairline) solid var(--c-ink);
  border-radius: var(--radius-base);
  padding: var(--tile-pad);
}
.hairline { height: var(--hairline); background: var(--c-rule); }
.label-mono {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--c-muted);
}
.btn-primary {
  width: 100%; min-height: 48px;
  background: var(--c-ink); color: var(--c-paper);
  border: var(--hairline) solid var(--c-ink);
  border-radius: var(--radius-base);
  font-family: var(--font-mono); font-weight: 500;
  letter-spacing: 0.1em; text-transform: uppercase;
}
.btn-outline {
  background: var(--c-paper); color: var(--c-ink);
  border: var(--hairline) solid var(--c-ink);
  /* same radius / mono label as primary */
}
.btn-ghost-icon {
  background: transparent; border: none;
  width: 32px; height: 32px; /* ~14px icon */
}
.input, .select, .textarea {
  background: var(--c-paper);
  border: var(--hairline) solid var(--c-ink);
  border-radius: var(--radius-base);
  font-family: var(--font-mono); /* numeric fields */
}
.input::placeholder { color: color-mix(in oklch, var(--c-muted) 60%, transparent); }
```

PWA-lite chrome (vs full Flutter shell): **header** with brand + date subtitle + sync micro-label + theme toggle; **bottom nav** with Log + History only (no Metrics / Maint / Settings gear).

---

## 2. Log screen — field map

**Implementation status:** `client/lib/app/pages/log_page.dart` and `history_page.dart` implement the Android contract on `main` (CES-39 phase 3 landed 2026-05). Normative fields: [`../product/ux/DATA_CONTRACTS.md`](../product/ux/DATA_CONTRACTS.md) §Fill-up entry + [`../product/ux/cestovni-views.md`](../product/ux/cestovni-views.md).

### Fields (display order for PWA-lite)

| # | Field | UI control | Storage (canonical) | Required | Validation / default |
|---|-------|------------|---------------------|----------|----------------------|
| 1 | Vehicle | `<select>` | `vehicle_id` (UUID) | Yes | Live vehicles: `deleted_at IS NULL AND archived_at IS NULL`, ordered by `name ASC` (matches `VehiclesRepository.watchLive`). Empty list → blocking empty state (see §8 Q2). |
| 2 | Date/time | `<input type="datetime-local">` | `filled_at` ISO-8601 UTC | Yes | Default: now (local wall → UTC on save). Must not be >24h in future (`validateInsert`). |
| 3 | Odometer | number input | `odometer_m` INT64 meters | Yes | User enters km or mi per cached `settings.preferred_distance_unit`; convert to meters at save (`si-units.md`: `1 km = 1000 m`, `1 mi = 1609.344 m`, banker's rounding). Integer display (0 decimals). Non-negative. Monotonic vs prior fill-ups unless `odometer_reset=true`. |
| 4 | Volume | number input | `volume_uL` INT64 µL | Yes | User enters L or gal per cached `settings.preferred_volume_unit`; convert to µL at save. 2 decimal entry allowed. Non-negative. |
| 5 | Total price | number input | `total_price_cents` INT64 | Yes | User enters major currency; convert to cents (`× 100`, banker's rounding). Non-negative. |
| 6 | Currency | hidden or read-only chip | `currency_code` CHAR(3) | Yes | Default from cached `settings.currency_code`. |
| 7 | Full fill | toggle (switch) | `is_full` boolean | Yes | Default `true`. Affects consumption math elsewhere — not computed on device. |
| 8 | Notes | `<textarea>` | `notes` TEXT nullable | No | Max 500 chars. |
| 9 | Missed before | toggle (advanced) | `missed_before` boolean | No | Default `false`. Helper text per DATA_CONTRACTS §Fill-up flag UX. |
| 10 | Odometer reset | toggle (advanced) | `odometer_reset` boolean | No | Default `false`. Not allowed on first fill-up for vehicle. |

**Not in PWA-lite Phase 1:** station, grade, draft-save/resume (`drafts` table), receipt photo.

### Save flow

On Save (after client-side validation mirroring `client/lib/consumption/validation.dart#validateInsert`):

1. Generate `id` = UUIDv4 (`protocol_writes.newUuid`).
2. Generate `mutation_id` = UUIDv4 (stored on row — separate from outbox `mutation_id` at enqueue per sync-protocol).
3. Set `updated_at` = ISO-8601 UTC now.
4. Leave `user_id`, `row_version`, `deleted_at` null until server hydrate.
5. Write row to IndexedDB `fill_ups` store.
6. Enqueue IndexedDB `outbox` row: `{ mutation_id, table: 'fill_ups', op: 'insert', row_id: id, payload_json: <full row snake_case>, enqueued_at, attempts: 0 }`.
7. Mark UI sync status `PENDING`; attempt flush if online.
8. Feedback: inline success on form (no toast spam); return focus ready for next entry.

### Consumption logic — do NOT implement on device

`client/lib/consumption/` (economy, rounding, adapters) is **out of scope**. PWA-lite runs entry validation only.

---

## 3. History screen — list contract

**Implementation status:** Flutter `client/lib/app/pages/history_page.dart` is **implemented on `main`** (CES-39 phase 3). **PWA-lite** `client/web-lite/` History is a **subset** (read-only rows, no edit/delete/flip-card). Full Flutter target (`cestovni-views.md` §History) still lacks Maint filter chip until **[CES-67](https://linear.app/personal-interests-llc/issue/CES-67)**.

### PWA-lite History (Phase 1+2)

| Aspect | Contract |
|--------|----------|
| Scope | Fill-ups only (no maintenance rows). Active vehicle from header selector (same session state as Log). |
| Ordering | `filled_at DESC`, then `id DESC` (matches `FillUpsRepository.watchForVehicle`; no separate `created_at` on client). |
| Row display | Date (local TZ from cached `settings.timezone`), vehicle name, volume (preferred unit, 2 dp), odometer (preferred unit, 0 dp), total price (2 dp + currency). |
| Sync pill | `PENDING` if outbox row exists for `row_id`; `SYNCED` if flushed with server `status: applied|duplicate`; `ERROR` if dead-letter. |
| Empty state | Ledger-card with muted copy + link hint to Log tab. |
| Grouping | **None** in Phase 1+2 (flat list; month grouping deferred). |
| Row actions | **Read-only** — no edit, delete, or flip-card in Phase 1+2. |
| Sync status elsewhere | Not surfaced in Flutter History today (outbox/M3 not wired). PWA-lite adds header micro-label + row pills. |

---

## 4. Data shapes

### `fill_ups` row (IndexedDB + outbox payload)

Mirrors `client/lib/db/tables/fill_ups.dart` + `protocol.dart`:

| Column | Type | Required on create | Notes |
|--------|------|-------------------|-------|
| `id` | UUID string | Yes | Client-generated UUIDv4 |
| `vehicle_id` | UUID | Yes | FK to vehicles |
| `filled_at` | ISO-8601 UTC string | Yes | |
| `odometer_m` | integer | Yes | Canonical meters |
| `volume_uL` | integer | Yes | Canonical µL |
| `total_price_cents` | integer | Yes | |
| `currency_code` | string(3) | Yes | ISO-4217 uppercase |
| `is_full` | boolean | Yes | |
| `missed_before` | boolean | Yes | default false |
| `odometer_reset` | boolean | Yes | default false |
| `notes` | string \| null | No | |
| `user_id` | UUID \| null | No | Server hydrate |
| `row_version` | integer \| null | No | Server hydrate |
| `updated_at` | ISO-8601 UTC | Yes | Client on write |
| `deleted_at` | null | Yes | null on insert |
| `mutation_id` | UUID | Yes | Client on write; new UUID on each amend (PWA-lite: insert only in Phase 1+2) |

Decimals are **never** stored — integers only per `si-units.md`.

### `vehicles` row (picker cache)

Minimum fields for picker from `client/lib/db/tables/vehicles.dart`:

| Column | Type | Picker use |
|--------|------|------------|
| `id` | UUID | value |
| `name` | string 1–80 | label |
| `fuel_type` | enum string | optional subtitle |
| `archived_at` | null for live | filter |
| `deleted_at` | null for live | filter |

Full vehicle CRUD is **not** on PWA-lite.

### `outbox` row (IndexedDB)

Mirrors `client/lib/db/tables/outbox.dart` + `sync-protocol.md`:

| Column | Type | Notes |
|--------|------|-------|
| `id` | auto-increment | Local only |
| `mutation_id` | UUID | Generated **once at enqueue**; reused on retry |
| `table` | `'fill_ups'` | |
| `op` | `'insert'` | Phase 1+2 insert only |
| `row_id` | UUID | = fill_ups.id |
| `payload_json` | JSON string | Full row snake_case |
| `enqueued_at` | ISO-8601 | |
| `attempts` | integer | Increment on retry |
| `last_error` | string \| null | |

**Android status:** `FillUpsRepository.create` / `amend` / `softDelete` now write `fill_ups` **and** enqueue the outbox in a single Drift transaction (CES-44 gate slice, 2026-05-29). `OutboxRepository` coalesces pending updates per `sync-protocol.md` §"Fill-up lifecycle". `vehicles` / `settings` outbox wiring is deferred until after the gate (still no enqueue from `VehiclesRepository`).

**Idempotency:** Protocol uses `mutation_id` in JSON body (`POST /mutations`), **not** an `Idempotency-Key` HTTP header. Server dedupes by `mutation_id`.

### `settings` cache (read-only on PWA-lite)

From `client/lib/db/tables/settings.dart`: `preferred_distance_unit`, `preferred_volume_unit`, `currency_code`, `timezone`. Bootstrap defaults if absent: `km`, `L`, `EUR`, `Europe/Prague` (match `SettingsRepository` bootstrap — verify in code during implementation).

### Schema migrations

Client at `schema_version` 2 (`client/lib/db/migrations/schema_steps.dart`). PWA-lite IndexedDB schema is **logical mirror** of v2 tables it uses (`vehicles`, `fill_ups`, `outbox`, `settings`, `sync_meta`) — no Drift/OPFS.

---

## 5. Backend API

### Existing endpoint spec

**Documented:** `POST /mutations` batch upload per [`sync-protocol.md`](sync-protocol.md).

**Implemented in this repo:** **No.** No `server/`, `api/`, or `backend/` directory. No Postgres migrations. No HTTP client in `client/lib/`.

Self-host runbook references `/api/v1/vehicles` — suggests prefix **`/api/v1/`** but mutations path is not confirmed in a live handler.

### Request shape (normative)

```json
POST /api/v1/mutations   /* path TBC — see open questions */
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "mutations": [{
    "mutation_id": "<uuid>",
    "table": "fill_ups",
    "op": "insert",
    "row_id": "<uuid>",
    "payload": { "vehicle_id": "…", "filled_at": "…Z", "odometer_m": 12345000, … }
  }]
}
```

### Response shape

Per-result: `{ mutation_id, row_id, row_version, server_updated_at, status: "applied"|"duplicate"|"rejected", error? }`.

### Auth

ADR 001: JWT/OIDC, deny-by-default. **No client auth implementation exists yet.** PWA-lite must match whatever auth the backend expects once built.

### Pull endpoints (for vehicle/settings cache + cross-device history)

- `GET /api/v1/changes?table=vehicles&since=0&limit=200`
- `GET /api/v1/changes?table=fill_ups&since=0&limit=200`
- `GET /api/v1/changes?table=settings&since=0&limit=200`

Used on first online session to populate IndexedDB caches.

---

## 6. PWA / manifest / icons

**On `main` today:** `client/web/` **does not exist** (Flutter web spike artifacts were never merged).

Phase 1+2 must create fresh under `client/web-lite/`:

| Asset | Action |
|-------|--------|
| `manifest.json` | New: `name: "Cestovni"`, `short_name: "Cestovni"`, `start_url: "/"`, `display: "standalone"`, `theme_color: "#1a1a2e"`, `background_color: "#1F1B16"` (dark paper), icons 192 + 512 |
| Icons | Copy from `spike/pwa-offline` branch `client/web/icons/` **or** export from `client/android/app/src/main/res/mipmap-*` — not present on main |
| `_headers` | Cloudflare Pages: `Service-Worker-Allowed: /` only. **No COOP/COEP** (broke iOS offline in spike). `/*.wasm` rule not needed for PWA-lite. |
| `sw.js` | Precache `index.html`, `app.js`, `styles.css`, `manifest.json`, fonts, icons — target **≤50 KB** excluding fonts |

---

## 7. Do NOT re-implement (server / Android concerns)

| Module | Reason |
|--------|--------|
| `client/lib/consumption/` economy / MPG / L/100km | Display-only derivations; Android + backend |
| Price-per-liter normalization | Derived at render |
| Maintenance entries | Out of iPhone scope |
| Metrics / charts | Android only |
| Export / ZIP | Android only |
| Photo pipeline / OPFS | Phase 3 deferred |
| Draft save/resume | Uses local `drafts` table — defer |
| Dead-letter UX beyond minimal ERROR pill | Full UX in sync-protocol Settings → Backup — defer fancy sheet to Phase 2 minimum (retry button in header tap target) |

PWA-lite **should** implement: SI unit conversion at save/display, `validateInsert` rules, outbox enqueue + flush, minimal auth token storage.

---

## Gate criteria

See [`pwa-lite-gate.md`](pwa-lite-gate.md) for the testable checklist. PWA-lite starts only after Android E2E proof on `main`.

## Constraints from Android

Captured at gate pass (2026-05-29) from running Android slice code; PWA-lite must mirror these byte-for-byte so server idempotency works across surfaces.

### Mutation payload shape (per `FillUpsRepository._payload`)

Source: `client/lib/db/repositories/fill_ups_repository.dart` (CES-44). Each `mutations[].payload` for `op=insert`/`update` carries these keys; `op=soft_delete` sends `payload: null`.

```json
{
  "id": "<uuid v4>",
  "vehicle_id": "<uuid v4>",
  "filled_at": "2026-05-29T10:30:00.000Z",
  "odometer_m": 123456000,
  "volume_uL": 41500000,
  "total_price_cents": 5876,
  "currency_code": "EUR",
  "is_full": true,
  "missed_before": false,
  "odometer_reset": false,
  "notes": "free text or null",
  "updated_at": "2026-05-29T10:30:00.000Z",
  "deleted_at": null,
  "mutation_id": "<row-level uuid — distinct from outbox enqueue id>"
}
```

- All canonical physical columns are **INT64** (`odometer_m`, `volume_uL`, `total_price_cents`) per `si-units.md`. Never JSON-encoded as decimals.
- `currency_code` matches `GLOB '[A-Z][A-Z][A-Z]'` (Drift CHECK constraint).
- `notes` is nullable up to 500 chars (DB CHECK).
- `user_id` and `row_version` are **server-assigned** and never sent by the client.

### Envelope (per `SyncClient._serialize`)

Source: `client/lib/sync/sync_client.dart`. Outbox-derived envelope, batch ≤100 mutations per request:

```json
{
  "mutations": [
    {
      "mutation_id": "<outbox enqueue id — generated once in OutboxRepository._insertRow, reused on retry>",
      "table": "fill_ups",
      "op": "insert | update | soft_delete",
      "row_id": "<fill_ups.id>",
      "payload": { /* see above; omitted entirely for soft_delete */ }
    }
  ]
}
```

### Auth header / token storage

Source: `client/lib/sync/sync_client.dart#postMutations` + `client/lib/sync/sync_config.dart`.

```
Authorization: Bearer <token>
Content-Type: application/json
```

- Token sourced from compile-time defines (Android M3 slice): `--dart-define=CESTOVNI_SYNC_TOKEN=<bearer>` + `--dart-define=CESTOVNI_SYNC_URL=<base>`. PWA-lite stores its token in `localStorage` (`pwa-lite-phase1-2.md` default #4); same `Authorization: Bearer …` header on the wire.
- No `Idempotency-Key` HTTP header — idempotency is body-only via `mutation_id`, matching `sync-protocol.md` §"Client outbox" + server stub.

### API paths

| Method | Path                                            | Used by      |
|--------|-------------------------------------------------|--------------|
| POST   | `/api/v1/mutations`                             | Push (CES-44 flush worker) |
| GET    | `/api/v1/changes?table=fill_ups&since=N&limit=N` | Pull (PWA-lite bootstrap) |

Base URL is configurable. Android emulator → host: `http://10.0.2.2:<port>`. Physical Android → laptop on LAN: `http://<host-ip>:<port>` (must use `adb reverse tcp:<port> tcp:<port>` or LAN address; the loopback alias does not apply to USB-tethered devices).

### Error codes / retry behavior

Source: `client/lib/sync/sync_client.dart#_isStatusRetriable` + `outbox_flush_worker.dart`.

| HTTP status | Action                                          |
|-------------|-------------------------------------------------|
| 200         | Per-result `applied` / `duplicate` → delete outbox row; `rejected` → record `last_error`, retain row (dead-letter UX is CES-45) |
| 401         | Retriable (token refresh path) — record `last_error`, retain row |
| 4xx (others) | Non-retriable — retain row + record error; CES-45 surfaces dead-letter UI |
| 429         | Retriable — record `last_error`, retain row (no `Retry-After` parsing in gate slice) |
| 5xx         | Retriable — record `last_error`, retain row    |
| transport error (no response) | Retriable                          |

PWA-lite must reproduce this matrix and persist `attempts` + `last_error` on each retry attempt.

### Lifecycle coalescing

Source: `OutboxRepository.enqueueUpdate` / `enqueueSoftDelete`.

- Pending **insert** + later **update** for same `row_id` → in-place payload rewrite (server only sees the final snapshot; original `mutation_id` retained).
- Pending **insert/update** + **soft_delete** for same `row_id` → drop the pending rows, enqueue a fresh `soft_delete` (no point inserting + deleting across the wire if nothing synced).
- Successful flush deletes the outbox row; future `amend` on the now-synced row enqueues a fresh `update` (no coalescing across the sync boundary).

## 8. Open questions (deferred to gate)

Discovery captured nine product questions in [`../product/prompts/pwa-lite-discovery.md`](../product/prompts/pwa-lite-discovery.md). **Do not guess** — resolve each from Android implementation when the gate passes; record answers in § Constraints from Android above.

---

## 9. Sized estimate (Phase 1+2 combined)

| File | Est. LOC |
|------|----------|
| `index.html` | ~120 |
| `styles.css` | ~350 |
| `app.js` (UI + IDB + validation + sync) | ~650 |
| `sw.js` | ~80 |
| `manifest.json` + `_headers` | ~40 |
| `idb.js` or inline schema helpers | ~200 |
| Backend stub/handler (if in scope) | ~300–800 |
| **Total frontend** | **~1,400** |

**Wall-clock (Cursor, one engineer-equivalent):** **2–3 days** for frontend + IDB + SW + iPhone smoke test; **+1–2 days** if minimal backend must be built in-repo.

### Top three risks (post-discovery)

1. **No backend in repo** — Phase 2 sync cannot E2E without new server work or external dependency; highest schedule risk.
2. **Vehicle/settings bootstrap** — offline-first Log requires cached vehicles; without Android-side vehicle creation path or backend pull, drivers hit a dead end.
3. **Auth gap** — no existing client auth pattern to copy; PWA-lite login UX is undefined.

---

## Phases

| Phase | Deliverable | Gate |
|-------|-------------|------|
| 0 | This document + discovery | Complete |
| Gate | Android E2E + constraints doc | [`pwa-lite-gate.md`](pwa-lite-gate.md) all items on `main` |
| 1 | UI + IndexedDB offline shell | **Done** — merged to `main` (PR #3, `d10c115`) |
| 2 | Sync push/pull (`POST /mutations`, `GET /changes`) | **Done** — merged `main` PR #4 (`8c1f1a8`); desktop E2E vs dev stub; iPhone T1 validated separately by product |
| 2b | Pages preview deploy + install doc | **Next** — [`pwa-lite-phase3-deploy.md`](../product/prompts/pwa-lite-phase3-deploy.md); Linear child of CES-62 |
| 3 | Receipt photos | After deploy + iPhone smoke |
