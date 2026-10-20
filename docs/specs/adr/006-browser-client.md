# ADR 006: Browser client for non-Android users (phone-first)

**Status:** Proposed
**Date:** 2026-10-20
**Linear:** [CES-72](https://linear.app/personal-interests-llc/issue/CES-72)
**Supersedes in part:** [ADR 005](005-distribution-channels.md) iPhone-as-only-non-Android-channel; does **not** reopen Flutter web as an iPhone offline PWA ([spike NO-GO](../../archive/spike-pwa-offline/spike-pwa-offline.md))

## Context

- Android Flutter + Drift is the primary client ([ADR 003](003-mobile-stack.md)). M0–M2 are closed on `main`.
- Stage 1 non-Android path was iPhone **PWA-lite** ([ADR 005](005-distribution-channels.md) + [addendum](005-addendum-pwa-lite-ios.md)). Product parked that path (CES-62 / CES-63). Code stays on `main` (`client/web-lite/`); it is not deleted and is not the portal.
- Flutter web as an **installed offline PWA on iOS Safari** is **NO-GO** (Safari 26.1 white-screen / storage fragility). That verdict stands.
- Product wants a **web portal** so people without the Android app can still use Cestovni. **Most of those clients will open it in a phone browser**, not a laptop.

ADR 001’s “no product-facing admin/dashboard” still holds. This is a **second client** on the app-owned API, not provider console UI.

## Decision criteria

1. **Phone-browser-first.** Layout, input, and performance are judged on mobile Safari (iOS) and Chrome (Android). Desktop is a stretch, not the design target.
2. **Honest offline story.** Do not promise offline fill-up in the portal if that reopens the Flutter web iOS-Safari failure.
3. **One product contract.** Same ADR 001 endpoints and `data-model.md` columns as Android. No portal-only schema.
4. **Do not grow PWA-lite** into a full app. It is a parked Log/History capture surface.
5. **No portal implementation** until this ADR is **Accepted**.

## Options considered

1. **Keep PWA-lite as the non-Android product** — rejected. Product parked CES-62/63.
2. **Revive Flutter web as an installed offline PWA on iPhone** — rejected. Spike NO-GO stands.
3. **Desktop-first “portal”** — rejected. Product: most users will be on phone browsers.
4. **New browser client, phone-first, online against M3** — **selected (proposed).**
5. **New browser client with its own offline DB** — deferred. Third storage stack (IndexedDB / WASM SQLite) is a later ADR if product requires offline-on-the-phone without the Android app.

## Decision (proposed locks — 2026-10-20)

| Lock | Choice |
|------|--------|
| Audience | **Phone browsers primary** (iOS Safari, Android Chrome). Desktop/laptop secondary. |
| Kind | Second **product client**, not an admin dashboard. |
| Online / offline | **Online-first.** Signed-in backup/restore per ADR 002. Offline fill-up on iPhone stays with parked PWA-lite; the portal does **not** claim zero-network logging in v1. |
| Capability (v1 draft) | Log + History + vehicles + settings + signed-in backup. Metrics / maintenance / ZIP / photos are **not** assumed; lock the matrix when this ADR is Accepted. |
| Stack | **Not chosen.** Compare after Accept: mobile-web (HTML/CSS/JS) vs Flutter web **as an online site** (not an offline iOS PWA). Reusing `client/web-lite/` as the portal is **out**. |
| iPhone PWA-lite | **Parked.** Leave `client/web-lite/` and Pages CI as-is. |
| App Store native iOS | Still deferred ($99/yr). |
| M3 | **Prerequisite** for a useful online portal. CES-42 → CES-43 before portal implementation. Dev stub is not CES-43. |
| Android | Unchanged primary client. CES-71 remains Android schema hygiene; not blocked by this ADR. |

## Consequences

- **Positive:** Non-Android users get a path that matches how they will actually open the product (phone browser). iPhone offline PWA investment stops leaking into a different problem.
- **Negative:** Phone users **without network** cannot log in the portal. That is an accepted v1 gap unless product later funds an offline browser stack.
- **Mobile Safari is in scope** as a *website*, not as Add-to-Home-Screen offline. Safe-area, viewport, session cookies / token storage, and `inputmode` are portal acceptance items.
- **M3 cost** starts when this ADR is Accepted — first real hosted Postgres/API ticket.
- ADR 003 “second client” revisit gate is now **open**. ADR 005 distribution table will be amended on Accept.

## Non-goals

- Implementing the portal, Flutter `client/web/`, or a new web package in this change.
- Deleting or extending `client/web-lite/` for portal features.
- Product-facing admin/ops dashboard (ADR 001).
- Live multi-device merge (v1.x, ADR 002).
- App Store / TestFlight.

## Revisit / Accept

Product **Accepts** this ADR (status flip + Linear comment) before any portal spike or M3 coding is scheduled. On Accept, amend ADR 005’s audience table and pick a stack issue.

## Related

- [`PRODUCT_BRIEF.md`](../../product/PRODUCT_BRIEF.md) — 2026-10-20 change log
- [`005-distribution-channels.md`](005-distribution-channels.md), [`005-addendum-pwa-lite-ios.md`](005-addendum-pwa-lite-ios.md)
- [`003-mobile-stack.md`](003-mobile-stack.md)
- [`001-backend-api-boundary.md`](001-backend-api-boundary.md) — client contract; no dashboard dependency
- [`002-backup-sync-layer.md`](002-backup-sync-layer.md), [`../sync-protocol.md`](../sync-protocol.md)
- [`../../archive/spike-pwa-offline/spike-pwa-offline.md`](../../archive/spike-pwa-offline/spike-pwa-offline.md)
