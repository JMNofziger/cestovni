# ADR 005: Stage 1 distribution channels (Android native + iOS PWA)

**Status:** Accepted
**Date:** 2026-05-17
**Accepted on:** 2026-05-17
**Linear:** Distribution pivot epic (CES-dist) — document before PWA offline spike

## Context

- Stage 1 requires **sustainable deployment with no recurring platform fees** (Apple Developer Program **$99/year** is out of scope for now).
- Product audience is roughly **70% Android / 30% iPhone**; iPhone users still need a credible install path without the App Store.
- The client is **Flutter + Drift** per [ADR 003](003-mobile-stack.md); significant M0–M1 work lives under [`client/`](../../../client/).
- Store-oriented compliance copy exists ([`platform-compliance-v1.md`](../platform-compliance-v1.md), [`launch-copy-v1.md`](../../product/launch-copy-v1.md)) but **App Store submission is deferred** to a later stage.

## Decision criteria

1. **Recurring cost** — minimize platform and ops fees at low user counts.
2. **Offline-first** — core fill-up logging must work without network on each channel we ship.
3. **Reuse Flutter investment** — no second client stack for iPhone in Stage 1.
4. **Honest capability matrix** — document what iOS PWA cannot do vs Android native.
5. **Continuity** — path to native iOS App Store later without rewriting the product contract ([ADR 001](001-backend-api-boundary.md)).

## Options considered

1. **App Store + Play (dual store)** — best discoverability; **fails** recurring-cost criterion (Apple annual fee).
2. **Android APK sideload + defer iPhone** — cheapest; **fails** ~30% iPhone audience.
3. **Android native + iOS installable PWA (Flutter web)** — one codebase with platform deltas; **selected**.
4. **AltStore / enterprise sideload iOS** — fragile UX; **rejected**.

## Decision

**Stage 1 distribution:**

| Audience | Channel | Platform fee | Client surface |
|----------|---------|--------------|----------------|
| Android (~70%) | **Direct APK** (primary); Play Store optional ($25 once) | $0 recurring (APK); $25 one-time if Play | Flutter **native** (existing `client/android/`) |
| iPhone (~30%) | **Installable PWA** (Add to Home Screen) | $0 store | Flutter **web** build + static hosting |
| Native iOS App Store | **Deferred** | $99/year when accepted | Native `client/ios/` compile may continue in PR CI only; **no weekly iOS CI** until re-scoped |

**PWA feasibility is not assumed.** A timeboxed spike ([`spike-pwa-offline.md`](../spike-pwa-offline.md)) must pass before M-dist iOS PWA engineering is treated as GO.

## iOS PWA capability matrix (user-visible)

Engineering and in-app copy must reflect this table; do not silently degrade.

| Capability | Android native | iOS PWA (Flutter web) | Stage 1 |
|------------|----------------|----------------------|---------|
| Offline structured data (Drift) | Full | WASM + OPFS — **spike gate** | Spike → GO/NO-GO |
| Receipt photos + TTL | [`photo-pipeline.md`](../photo-pipeline.md) | Camera + OPFS; OS TTL not enforced | Spike scopes: full / limited / deferred |
| ZIP export (foreground) | [`export-v1.md`](../export-v1.md) | Browser download; no background job | Limited on iOS PWA |
| Background export notification | Native | Not available | Out of scope on iOS PWA |
| Share export | Native intent | Web Share API (iOS 15+) | Supported where API exists |
| Home screen icon | Launcher | Add to Home Screen | Supported |

## Cost table (Stage 1 target)

| Line item | Cost | Notes |
|-----------|------|-------|
| Apple Developer / App Store | **$0** | Deferred |
| Google Play | **$0** (APK) or **$25 once** | Optional discoverability |
| PWA static hosting | **$0** | Cloudflare Pages free tier; requires `_headers` for OPFS (not GitHub Pages) |
| Crash / telemetry backend | **$0** at low volume | [Glitchtip](https://glitchtip.com) self-host per [ADR 004 addendum](004-addendum-glitchtip-transport.md); SaaS free tier acceptable for earliest betas |
| Backup API | Managed free tier or self-host | [ADR 001](001-backend-api-boundary.md) — separate from store fees |

## Technical prerequisites (PWA spike)

Documented blockers the spike must address:

1. [`client/lib/db/app_database.dart`](../../../client/lib/db/app_database.dart) imports `dart:io` and uses `NativeDatabase` — **web build fails** until a platform-conditional open path exists.
2. [`client/pubspec.yaml`](../../../client/pubspec.yaml) has `sqlite3_flutter_libs` (native only); web needs `drift_flutter` (WASM + OPFS).
3. No [`client/web/`](../../../client/web/) tree yet — first `flutter build web` scaffolds it.
4. Photo pipeline uses app-sandbox filesystem paths — web needs OPFS or scoped deferral ([`photo-pipeline.md`](../photo-pipeline.md)).

Spike charter: [`spike-pwa-offline.md`](../spike-pwa-offline.md). Execution prompt: [`../../product/prompts/pwa-offline-spike.md`](../../product/prompts/pwa-offline-spike.md).

## CI posture

- **Paused:** weekly native iOS workflow moved to [`ci/paused/verify-ios-weekly.yml`](../../../ci/paused/verify-ios-weekly.yml) — **no GitHub triggers** until native iOS distribution returns.
- **PR / dispatch:** [`verify-full.yml`](../../../.github/workflows/verify-full.yml) may still build iOS on PRs for compile health; that is **not** a distribution channel.
- **Future:** `client-web` job in verify-full when web target is enabled (after spike).

## Consequences

- **Positive:** $0 recurring store fees; Android lane unblocked; iPhone users get an install path if spike passes.
- **Negative:** two platform surfaces (native vs web); M2 export and M1 photo work need narrow `kIsWeb` guards; App Store polish deferred.
- **Risk:** PWA offline fails on Safari — mitigate with spike NO-GO path and honest iOS messaging.

## Revisit gates (native iOS App Store)

Re-open this ADR when **any** of:

- Product accepts **$99/year** Apple Developer Program as sustainable.
- EU / alt-store rules make non–App Store native distribution viable at our scale.
- PWA spike is **NO-GO** and product requires full native parity on iPhone.

On revisit: restore [`ci/paused/verify-ios-weekly.yml`](../../../ci/paused/verify-ios-weekly.yml) to `.github/workflows/`, update compliance store sections, and schedule App Store submission work under Stage 6.

## Related

- [ADR 003](003-mobile-stack.md) — Flutter + Drift (amended for web-as-distribution-channel).
- [ADR 004](004-telemetry-crash-sdk.md) + [addendum](004-addendum-glitchtip-transport.md) — Glitchtip transport.
- [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md) — **M-dist** parallel track.
- [`../../product/PRODUCT_BRIEF.md`](../../product/PRODUCT_BRIEF.md) — change log 2026-05-17.
