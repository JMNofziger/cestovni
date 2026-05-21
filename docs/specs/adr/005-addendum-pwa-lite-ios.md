# ADR 005 addendum: iPhone PWA-lite (post-spike)

**Status:** Accepted
**Date:** 2026-05-21
**Parent:** [005-distribution-channels.md](005-distribution-channels.md)
**Spec:** [`../pwa-lite-v1.md`](../pwa-lite-v1.md)

## Context

The Flutter web PWA offline spike ([archive](../../archive/spike-pwa-offline/)) closed **NO-GO** on iOS Safari 26.1. Product also ruled out the $99/yr Apple Developer Program — App Store / TestFlight is not a Stage 1 option.

## Decision

Amend Stage 1 iPhone distribution:

| Before (ADR 005) | After (this addendum) |
|------------------|----------------------|
| Flutter **web** PWA | **PWA-lite** — vanilla HTML + JS + IndexedDB at `client/web-lite/` |
| Single Flutter codebase for iPhone | Thin iPhone capture surface + Flutter **native on Android only** |
| Spike gate before M-dist | Spike complete; engineering proceeds on [`pwa-lite-v1.md`](../pwa-lite-v1.md) |

Android (~70%), hosting costs ($0), and App Store deferral are unchanged.

## iOS capability matrix (revised)

| Capability | Android native | iPhone PWA-lite | Stage 1 |
|------------|----------------|-----------------|---------|
| Offline fill-up log | Full | IndexedDB queue | **GO** |
| Offline history + sync status | Full | IndexedDB read | **GO** |
| Full app (metrics, maintenance, export) | Full | Not on iPhone | Android only |
| Receipt photos | Full pipeline | Deferred (Phase 3) | Limited |
| ZIP export | Full | Not on iPhone | Android only |

## Consequences

- **Positive:** Reliable offline capture on iPhone without App Store fees; Android codebase unchanged.
- **Negative:** Two client surfaces (Flutter native + PWA-lite); theming must stay aligned via shared design tokens.
- **Risk:** iOS 7-day storage eviction — mitigate with backend as canonical store + prominent sync status.

## Related

- [`../pwa-lite-v1.md`](../pwa-lite-v1.md) — implementation spec
- [`../../archive/spike-pwa-offline/`](../../archive/spike-pwa-offline/) — spike record
