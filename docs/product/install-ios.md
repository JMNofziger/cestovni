# Installing Cestovni on iPhone (Stage 1 PWA-lite)

**Status:** **Blocked** — available after [`pwa-lite-gate.md`](../specs/pwa-lite-gate.md) passes and PWA-lite implementation ships ([`pwa-lite-v1.md`](../specs/pwa-lite-v1.md)).

iPhone users install Cestovni as a **web app** (Add to Home Screen), not from the App Store. See [ADR 005 addendum](../specs/adr/005-addendum-pwa-lite-ios.md) for capability limits vs Android native.

## Before you install

- Requires **Safari** on iOS 17+ (recommended).
- iPhone app covers **Log** and **History** only — full features (metrics, export) are on Android.

## Steps (to be finalized after deploy)

1. Open the Cestovni URL in **Safari** (link TBD — Cloudflare Pages).
2. Tap **Share** → **Add to Home Screen**.
3. Open **Cestovni** from the home screen icon.

## Related

- [`pwa-lite-v1.md`](../specs/pwa-lite-v1.md)
- [ADR 005](../specs/adr/005-distribution-channels.md)
