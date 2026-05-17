# Installing Cestovni on iPhone (Stage 1 PWA)

**Status:** Draft — available after [PWA offline spike](../specs/spike-pwa-offline.md) is **GO** or **GO-with-limits**.

iPhone users install Cestovni as a **web app** (Add to Home Screen), not from the App Store. See [ADR 005](../specs/adr/005-distribution-channels.md) for capability limits vs Android.

## Before you install

- Requires **Safari** on iOS 17+ (recommended).
- Some features differ from Android (photos, background export) — the app will disclose this on first launch when implemented.

## Steps (to be finalized after spike + deploy)

1. Open the Cestovni URL in **Safari** (link TBD — Cloudflare Pages).
2. Tap **Share** → **Add to Home Screen**.
3. Open **Cestovni** from the home screen icon (standalone window).

## Related

- [spike-pwa-offline.md](../specs/spike-pwa-offline.md)
- [ADR 005](../specs/adr/005-distribution-channels.md)
