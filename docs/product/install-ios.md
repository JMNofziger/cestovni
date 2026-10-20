# Installing Cestovni on iPhone (Stage 1 PWA-lite)

**Status:** **Draft / PARKED** (2026-10-20) — CES-62 / CES-63 deferred. PWA-lite Phase 1+2 + Pages CI remain on `main`. Do not finalize this doc until product unparks the iPhone path. Non-Android option is [ADR 006](../specs/adr/006-browser-client.md) (phone-browser portal, Proposed).

iPhone users install Cestovni as a **web app** (Add to Home Screen), not from the App Store. See [ADR 005 addendum](../specs/adr/005-addendum-pwa-lite-ios.md) for capability limits vs Android native.

## Before you install

- Requires **Safari** on iOS 17+ (recommended).
- iPhone app covers **Log** and **History** only — full features (metrics, export) are on Android.

## Steps (to be finalized after deploy)

1. Open the Cestovni URL in **Safari** (link TBD in this doc — production host `https://cestovni-pwa.pages.dev` exists; still needs `?api_base=` tunnel for T1).
2. Tap **Share** → **Add to Home Screen**.
3. Open **Cestovni** from the home screen icon.

## Related

- [`pwa-lite-v1.md`](../specs/pwa-lite-v1.md)
- [ADR 005](../specs/adr/005-distribution-channels.md)
