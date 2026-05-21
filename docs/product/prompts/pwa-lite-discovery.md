# Cursor discovery prompt — PWA-lite for iPhone (Option H, Phase 0)

**Mode:** Read-only / Ask mode.
**Goal:** gather everything needed for a tight Phase 1 execution prompt. **Do NOT modify files. Return a single structured Markdown report.**

## Context (do not re-derive)

- Flutter web PWA offline spike closed **NO-GO** on iOS Safari 26.1 — see [`docs/archive/spike-pwa-offline/`](../../archive/spike-pwa-offline/).
- **Selected path:** PWA-lite per [`docs/specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md) and [ADR 005 addendum](../../specs/adr/005-addendum-pwa-lite-ios.md). iPhone gets vanilla HTML + IndexedDB at the **root** of `cestovni-pwa.pages.dev`. **No Flutter web on iPhone.** Android keeps Flutter native.
- Two screens only on iPhone: **Log** (single fill-up entry) + **History** (reverse-chrono list with sync status).
- **Visual fidelity is a hard constraint.** The PWA-lite must reuse the existing paper-ledger design language documented in [`docs/product/ux/cestovni-styling.md`](../ux/cestovni-styling.md): OKLCH tokens, Fraunces serif / Inter sans / JetBrains Mono mono, ledger-card / ledger-tile / hairline-divider components, hard 1px ink borders, hard offset shadows (no blur), mono uppercase micro-labels.
- Sync status: **clear but minimal** — a single mono micro-label in the header strip plus a small per-row pill in History. No banners, no toasts on every state change.
- Backend already has an **outbox** table in the Flutter DB (`client/lib/db/tables/outbox.dart`) — the PWA-lite sync queue must align with whatever shape the existing Android client already produces so the backend serves both with one endpoint.

## Deliverable

Write one Markdown file at `docs/specs/pwa-lite-v1.md` — **update the Phase 0 placeholder sections** in the existing stub. Use only information you read from the repo — do **not** invent shapes. Where info is missing or ambiguous, list it under "Open questions for product" at the end; **do not guess**.

### 1. Visual contract (CSS-ready)

A compact translation of the design system into CSS-ready form. Read:

- `docs/product/ux/cestovni-styling.md` (full)
- `client/lib/app/theme/cestovni_tokens.dart`
- `client/lib/app/theme/cestovni_primitives.dart`
- `client/lib/app/theme/cestovni_typography.dart`
- `client/lib/app/theme/cestovni_theme.dart`

Produce:

- Table of **CSS custom property names** (`--c-paper`, `--c-ink`, etc.) mapped to OKLCH for light AND dark mode. Include semantic tokens (`accent`, `good`, `warn`, `bad`) and chart palette (not needed in Phase 1 but document).
- Typography stack: exact font families, weights, fallbacks, expected file sizes if self-hosted as woff2 Latin subset. Identify which weights are actually used in Log + History (minimize subset).
- Component recipes restated as CSS:
  - `.ledger-card` — surface, border, radius, shadow.
  - `.ledger-tile` — surface, border, radius, padding.
  - `.hairline` — divider.
  - `.label-mono` — uppercase mono micro-label.
  - `.btn-primary`, `.btn-outline`, `.btn-ghost-icon` — match § 7 of styling spec.
  - `.input`, `.select` — match § 8.

### 2. Log screen — exact field map

Read `client/lib/app/pages/log_page.dart` (and any `vehicle_form_page.dart` or models it uses). Document:

- Ordered list of fields visible to the driver: name, type, validation, default, placeholder.
- Vehicle picker behavior: where does the vehicle list come from, how is it cached, what happens when zero vehicles exist?
- Required vs optional fields. Numeric input rules (decimals for liters, integer for odometer km, etc.).
- Save flow: what records get written, what side-effects fire, what feedback is shown to the user.
- Any consumption / mileage derivation logic in `client/lib/consumption/` that the Log page uses today. (PWA-lite Phase 1 should NOT reproduce derivation — backend or Android cockpit can compute later.)

### 3. History screen — list contract

Read `client/lib/app/pages/history_page.dart`. Document:

- Row contents: what columns, what ordering, what date formatting.
- Empty state behavior.
- Any grouping (by day / month / vehicle?).
- Where sync status is surfaced today, if anywhere (it may not be).
- What user actions are available on a row (tap to edit? swipe to delete?). For PWA-lite Phase 1, document but do NOT implement edit / delete — read-only history is fine.

### 4. Data shape — fill-ups + vehicles + outbox

Read:

- `client/lib/db/tables/fill_ups.dart`
- `client/lib/db/tables/vehicles.dart`
- `client/lib/db/tables/outbox.dart`
- `client/lib/db/repositories/` (whichever files reference these tables)
- `client/lib/consumption/models.dart`

Document:

- The **canonical fill-up row shape** that gets written: column → type → required/optional → semantic meaning. Especially: how is `id` generated (UUID? client-side? server-side?), how is `captured_at` represented, what timezone conventions apply, how are decimal numbers stored (string vs num)?
- The **vehicle row shape** that the PWA-lite vehicle picker needs to consume.
- The **outbox row shape** — what does the Android client put in the outbox after a save, and what does the sync worker do with it? Specifically: is there an `Idempotency-Key` already generated on the device, or is one fabricated at sync time?
- Any existing **schema migrations** documented under `client/lib/db/migrations/` that the PWA-lite must NOT diverge from.

### 5. Backend API — existing sync endpoint(s)

Search the repo for:

- `POST.*fillup`, `POST.*outbox`, `/v1/fill`, `/api/v1/fill`, `sync`, `Idempotency-Key`
- The backend root folder (likely `server/`, `api/`, `backend/`, or under a separate top-level dir — discover and report).
- Whatever HTTP client lives in `client/lib/` (search for `dio`, `http`, `Client(`, `package:http`).

Document:

- **Does an endpoint already exist that accepts outbox rows?** If yes: full path + method + accepted body shape + auth header + idempotency convention. If no: confirm explicitly so we know Phase 2 must add one.
- Auth: how does the existing Android client authenticate today? Token-based? Session-based? Anonymous? The PWA-lite must use the same scheme.
- Error response shape (so PWA-lite knows how to surface failures).

### 6. PWA / manifest / icons reuse

Read:

- `client/web/manifest.json`
- `client/web/icons/`
- `client/web/_headers`

Document:

- Existing manifest fields (theme_color, background_color, display, icons array). Phase 1 should reuse icons + brand colors verbatim.
- The `_headers` setup on Cloudflare Pages — confirm we keep the no-COOP/COEP state (the old SW v7 baseline) since the PWA-lite doesn't need OPFS.

### 7. Recommendations to NOT re-implement

Be opinionated. List which Flutter-side logic the PWA-lite should treat as **server-side concerns** and skip on the device:

- Consumption / mileage calc?
- Price normalization?
- Anything else from `client/lib/consumption/`?

The PWA-lite is a **capture surface**, not a calculator. The Android cockpit and/or backend should remain the only place derivations happen — otherwise drift will accumulate.

### 8. Open questions for product

A bullet list of every ambiguity you hit while reading the repo. Examples of the kind of question we want surfaced:

- "Does `vehicles.color` map to one of the chart palette tokens or is it free OKLCH?"
- "Does the existing outbox already include `Idempotency-Key`, or does the sync worker generate one at flush time? (Affects whether we can keep `POST /v1/fillups/queue` shape identical between Android and PWA-lite.)"
- "Should PWA-lite History show items from other devices (i.e. pull from backend on open) or only items captured on this iPhone?"

Each question should be answerable in one or two sentences by the head of product. **Do not guess answers** — leave them open.

### 9. Sized estimate for Phase 1

Once sections 1–8 are filled in, give a refined estimate for Phase 1 (Capture + History UI, IndexedDB only, no backend yet):

- Estimated lines of code per file.
- Estimated wall-clock execution time for Cursor (assume one engineer-equivalent, Phase 1 only).
- Top three risks you see *after* having read the actual code.

## What to return

Do not write code. Do not modify any file outside `docs/specs/pwa-lite-v1.md`. Return the path to the file you created and a short message confirming the open-questions count.

Tag: `Phase 0 — PWA-lite discovery for iPhone`.
