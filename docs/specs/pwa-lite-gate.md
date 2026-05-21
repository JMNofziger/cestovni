# PWA-lite gate — Android E2E before iPhone work

**Status:** Active (2026-05-21, Option B — Android first)
**Spec:** [`pwa-lite-v1.md`](pwa-lite-v1.md)
**Delivery plan:** [`../product/delivery-plan-v1.md`](../product/delivery-plan-v1.md) § M-dist

PWA-lite iPhone engineering **must not start** until every checklist item below is true on `main`. PWA-lite ports the **proven** sync contract from running Android code — not specs alone.

## Gate checklist

PWA-lite work may start when **all** are true on `main`:

- [ ] CES-39: Android Log form saves fill-up locally with full DATA_CONTRACTS validation. *(Implemented on branch `docs/android-first-sequencing` — merge required.)*
- [ ] CES-39: Android History lists fill-ups for active vehicle. *(Same — merge phase 3 to `main`.)*
- [ ] M3 client slice: save enqueues `outbox` row; flush worker calls API.
- [ ] M3 server slice: `POST /api/v1/mutations` + `GET /api/v1/changes` accept fill-up insert (dev or staging OK).
- [ ] **E2E proof documented:** airplane-mode fill-up on Android → online → mutation `applied` → row returned by `GET /changes`.
- [ ] Constraints extracted to `pwa-lite-v1.md` § "Constraints from Android" (payload shape, auth header, error codes) — filled from **code**, not speculation.

## Acceptance test (E2E proof)

1. Android device: airplane mode ON.
2. Log one fill-up (Log tab) → appears in History (local).
3. Airplane mode OFF; wait for flush (or manual retry).
4. Verify server: `POST /api/v1/mutations` returns `status: applied` (or `duplicate` on retry).
5. Verify server: `GET /api/v1/changes?table=fill_ups` returns the row.

Document `mutation_id`, `row_id`, and environment (dev/staging) in the gate issue comment or `pwa-lite-v1.md` § Constraints from Android.

## What unlocks PWA-lite

| Deliverable | Linear | Notes |
|-------------|--------|-------|
| Log + History UI + validation | [CES-39](https://linear.app/personal-interests-llc/issue/CES-39) | Defines contract PWA-lite mirrors |
| Outbox enqueue + flush (minimal) | [CES-44](https://linear.app/personal-interests-llc/issue/CES-44) | Fill-up save → outbox → `POST /mutations` only; full restore/dead-letter (CES-45) after gate |
| API + auth (minimal) | [CES-43](https://linear.app/personal-interests-llc/issue/CES-43) | `POST /api/v1/mutations` + `GET /api/v1/changes` for `fill_ups` + bearer; full M3 scope remains on issue |

## Related

- [`pwa-lite-v1.md`](pwa-lite-v1.md) — blocked until gate passes
- [`../product/prompts/pwa-lite-phase1-2.md`](../product/prompts/pwa-lite-phase1-2.md) — **PAUSED**; do not execute
- [`../archive/spike-pwa-offline/`](../archive/spike-pwa-offline/) — Flutter web NO-GO (historical)
