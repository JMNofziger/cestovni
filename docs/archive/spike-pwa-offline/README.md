# Archive: Flutter web PWA offline spike (2026-05-17 — 2026-05-21)

**Verdict:** NO-GO — full Flutter web PWA offline failed on iPhone 13 mini / iOS 26.1 (T1 cold start, two runs).

**Forward path:** iPhone Stage 1 uses **PWA-lite** (vanilla HTML + IndexedDB). See [`../../specs/pwa-lite-v1.md`](../../specs/pwa-lite-v1.md).

| File | Contents |
|------|----------|
| [`spike-pwa-offline.md`](spike-pwa-offline.md) | Spike charter, acceptance tests, results |
| [`pwa-offline-spike.md`](pwa-offline-spike.md) | Historical Cursor execution prompt |
| [`ios-offline-strategy.md`](ios-offline-strategy.md) | Options analysis (A–H) and decision record |

Branch `spike/pwa-offline` may be deleted after this archive lands on `main`.
