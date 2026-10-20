# ADR 006: Browser client for non-Android users (phone-first)

**Status:** Accepted
**Date:** 2026-10-20
**Accepted on:** 2026-10-20
**Stack amendment:** 2026-10-20 (CES-73)
**Linear:** [CES-72](https://linear.app/personal-interests-llc/issue/CES-72) (acceptance), [CES-73](https://linear.app/personal-interests-llc/issue/CES-73) (stack)
**Supersedes in part:** [ADR 005](005-distribution-channels.md) iPhone-as-only-non-Android-channel; does **not** reopen Flutter web as an iPhone offline PWA ([spike NO-GO](../../archive/spike-pwa-offline/spike-pwa-offline.md))

## Context

- Android Flutter + Drift is the primary client ([ADR 003](003-mobile-stack.md)). M0--M2 are closed on `main`.
- Stage 1 non-Android path was iPhone **PWA-lite** ([ADR 005](005-distribution-channels.md) + [addendum](005-addendum-pwa-lite-ios.md)). Product parked that path (CES-62 / CES-63). Code stays on `main` (`client/web-lite/`); it is not deleted and is not the portal.
- Flutter web as an **installed offline PWA on iOS Safari** is **NO-GO** (Safari 26.1 white-screen / storage fragility). That verdict stands.
- Product wants a **web portal** so people without the Android app can still use Cestovni. **Most of those clients will open it in a phone browser**, not a laptop.

ADR 001's "no product-facing admin/dashboard" still holds. This is a **second client** on the app-owned API, not provider console UI.

## Decision criteria

1. **Phone-browser-first.** Layout, input, and performance are judged on mobile Safari (iOS) and Chrome (Android). Desktop is a stretch, not the design target.
2. **Honest offline story.** Do not promise offline fill-up in the portal if that reopens the Flutter web iOS-Safari failure.
3. **One product contract.** Same ADR 001 endpoints and `data-model.md` columns as Android. No portal-only schema.
4. **Do not grow PWA-lite** into a full app. It is a parked Log/History capture surface.
5. **No portal implementation** until this ADR is **Accepted**.

## Options considered

1. **Keep PWA-lite as the non-Android product** -- rejected. Product parked CES-62/63.
2. **Revive Flutter web as an installed offline PWA on iPhone** -- rejected. Spike NO-GO stands.
3. **Desktop-first "portal"** -- rejected. Product: most users will be on phone browsers.
4. **New browser client, phone-first, online against M3** -- **selected.**
5. **New browser client with its own offline DB** -- deferred. Third storage stack (IndexedDB / WASM SQLite) is a later ADR if product requires offline-on-the-phone without the Android app.

## Decision (accepted locks -- 2026-10-20)

| Lock | Choice |
|------|--------|
| Audience | **Phone browsers primary** (iOS Safari, Android Chrome). Desktop/laptop secondary. |
| Kind | Second **product client**, not an admin dashboard. |
| Online / offline | **Online-first.** Signed-in backup/restore per ADR 002. Offline fill-up on iPhone stays with parked PWA-lite; the portal does **not** claim zero-network logging in v1. |
| Stack | **Preact + TypeScript** (see [Stack selection](#stack-selection-ces-73) below). |
| iPhone PWA-lite | **Parked.** Leave `client/web-lite/` and Pages CI as-is. |
| App Store native iOS | Still deferred ($99/yr). |
| M3 | **Prerequisite** for a useful online portal. CES-42 -> CES-43 before portal implementation. Dev stub is not CES-43. |
| Android | Unchanged primary client. |

### Locked capability matrix (v1)

| Capability | Portal v1 | Notes |
|------------|-----------|-------|
| Log fill-up | **GO** | Core loop. Online-only (POST to M3 API). |
| History (read) | **GO** | GET from API; paginate. |
| Vehicle CRUD | **GO** | Create / edit / archive. |
| Settings (prefs) | **GO** | Units, currency, timezone, default vehicle. |
| Signed-in backup | **GO** | "Sync now" button; restore from server. |
| Offline fill-up | **NO** | Accepted v1 gap. Parked PWA-lite covers iPhone offline capture. |
| Metrics | **Deferred** | Server-side aggregation or client-side compute; not v1 portal. |
| Maintenance rules/events | **Deferred** | Lower priority for phone-browser users; Android-first feature. |
| Photos (attach/view) | **NO** | Photo pipeline is Android-only (camera sandbox, EXIF strip). |
| ZIP export/import | **NO** | Device-to-device path; not meaningful without local storage. |

## Stack selection (CES-73)

**Decision: Preact + TypeScript**, bundled with Vite, deployed as static assets.

### Candidates evaluated

| | Vanilla JS | Flutter web (online) | Preact + TS | Svelte + TS |
|---|---|---|---|---|
| **Bundle (gzip)** | 1--5 KB | 1.5--3 MB (CanvasKit) | ~3 KB + app (~20 KB) | ~2 KB + app (~18 KB) |
| **3G load** | < 1 s | 30--60 s | < 2 s | < 2 s |
| **Safari compat** | Perfect | Known viewport/keyboard issues | Clean | Clean |
| **Type safety** | None (or add TS build) | Dart (full) | TypeScript | TypeScript |
| **Code sharing with Flutter** | None | Maximum (same repo) | None (shared API contract) | None (shared API contract) |
| **Scales to 5+ views** | Painful (manual DOM) | Yes | Yes (components + preact-router) | Yes (components + SvelteKit) |
| **Maintenance cost** | Low for small scope; high beyond | One Dart codebase but web-specific workarounds | Second stack, but small | Second stack, but small |

### Rationale

1. **Bundle size is decisive.** Phone-browser-first on 3G means every kilobyte matters. Flutter web's CanvasKit WASM payload (~1 MB) plus compiled Dart (~0.5--2 MB) produces a 30--60 second first paint on a 400 Kbps connection. This is disqualifying.

2. **Flutter web HTML renderer** reduces bundle but degrades fidelity (font rendering, shadows, platform feel). It also does not escape the Dart-to-JS compilation size floor (~300 KB gzip for a non-trivial app). Still 5--10x larger than a lightweight JS framework.

3. **Code sharing is a false economy.** The Flutter client's value is Drift (local SQLite), offline-first architecture, and platform channels (camera, filesystem). The portal is online-only, no SQLite, no camera, no filesystem. The actual shared surface is the API contract (`sync-protocol.md` endpoints) and consumption math -- both thin enough to share as a JSON spec / typed fetch layer, not a framework.

4. **Vanilla JS doesn't scale.** `client/web-lite/` works at 1368 lines for Log + History + sync. The portal adds Vehicle CRUD, Settings, Backup, and multi-view navigation with auth. Manual DOM manipulation and state management become a maintenance burden without components or routing.

5. **Preact over Svelte.** Both are excellent. Preact wins on ecosystem breadth (React-compatible patterns, largest library ecosystem for edge cases), familiarity for future contributors, and zero-config TypeScript via Vite. Svelte's compiler-first approach is compelling but adds a build concept (Svelte-specific syntax) that narrows the contributor pool.

### Implementation shape (not started -- gated on M3)

```
portal/
  src/
    api/          # typed fetch wrappers against sync-protocol.md
    components/   # Preact components (Log, History, Vehicles, Settings, Backup)
    routes/       # preact-router pages
    main.tsx
  index.html
  vite.config.ts
  tsconfig.json
  package.json
```

- **No shared Dart code.** Portal speaks the same REST API as the Flutter client.
- **Consumption math** (L/100km, mpg) re-implemented in TypeScript -- ~50 lines, tested against the same golden fixtures in `tests/math/`.
- **Auth:** bearer JWT from M3 (CES-43). Token stored in `sessionStorage` (not `localStorage` -- session scoped, no persistent offline token).
- **Deploy:** static assets to Cloudflare Pages (same pipeline as `client/web-lite/`).

### What this does NOT decide

- Portal visual design (follows when implementation starts).
- Whether `preact-router` or a newer alternative (e.g. Wouter) is used -- decide at implementation time.
- Server-side rendering -- not needed for a phone-browser SPA with < 25 KB total.

## Consequences

- **Positive:** Non-Android users get a path that matches how they will actually open the product (phone browser). iPhone offline PWA investment stops leaking into a different problem. Preact + TS delivers sub-2-second loads on 3G.
- **Negative:** Phone users **without network** cannot log in the portal. That is an accepted v1 gap unless product later funds an offline browser stack. Two tech stacks (Dart + TypeScript) increase cognitive load for the solo maintainer.
- **Mobile Safari is in scope** as a *website*, not as Add-to-Home-Screen offline. Safe-area, viewport, session cookies / token storage, and `inputmode` are portal acceptance items.
- **M3 cost** starts now -- first real hosted Postgres/API ticket.
- ADR 003 "second client" revisit gate is now **open**. ADR 005 distribution table amended.

## Non-goals

- Implementing the portal, Flutter `client/web/`, or a new web package in this change.
- Deleting or extending `client/web-lite/` for portal features.
- Product-facing admin/ops dashboard (ADR 001).
- Live multi-device merge (v1.x, ADR 002).
- App Store / TestFlight.

## Related

- [`PRODUCT_BRIEF.md`](../../product/PRODUCT_BRIEF.md) -- 2026-10-20 change log
- [`005-distribution-channels.md`](005-distribution-channels.md), [`005-addendum-pwa-lite-ios.md`](005-addendum-pwa-lite-ios.md)
- [`003-mobile-stack.md`](003-mobile-stack.md) -- revisit gate triggered
- [`001-backend-api-boundary.md`](001-backend-api-boundary.md) -- client contract; no dashboard dependency
- [`002-backup-sync-layer.md`](002-backup-sync-layer.md), [`../sync-protocol.md`](../sync-protocol.md)
- [`../../archive/spike-pwa-offline/spike-pwa-offline.md`](../../archive/spike-pwa-offline/spike-pwa-offline.md)
