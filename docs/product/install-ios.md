# Installing Cestovni on iPhone (Stage 1 PWA-lite)

**Status:** **Draft** — PWA-lite Phase 1+2 shipped on `main` (PR #3 + #4). Finalize this doc when Cloudflare Pages preview deploy lands ([`prompts/pwa-lite-phase3-deploy.md`](prompts/pwa-lite-phase3-deploy.md)).

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
