# Spike: Flutter web PWA offline persistence (Safari iOS)

**Status:** Ready to execute — charter locked; results **TBD** by spike owner
**Type:** Timeboxed spike (3–5 days)
**Linear:** CES-dist / PWA offline spike
**Spec:** [ADR 005](adr/005-distribution-channels.md)
**Execution prompt:** [`../product/prompts/pwa-offline-spike.md`](../product/prompts/pwa-offline-spike.md)

## Goal

Prove that an **installed PWA on Safari iOS 17+** can run Cestovni's core offline path: open without network, persist structured data in Drift on web, and survive app close/reopen — before committing M-dist iOS PWA build work.

## Out of scope for this spike

- Production Cloudflare deploy (preview URL is enough).
- Full photo TTL pipeline parity ([`photo-pipeline.md`](photo-pipeline.md)) — test and **scope**, do not fully implement.
- ZIP export ([`export-v1.md`](export-v1.md)) — not required for GO/NO-GO on logging.
- Glitchtip / telemetry wiring (M4).
- App Store or native iOS distribution.

## Known blockers (must be resolved in spike branch)

| # | Blocker | File(s) |
|---|---------|---------|
| 1 | `dart:io` + `NativeDatabase` breaks web compile | [`client/lib/db/app_database.dart`](../../client/lib/db/app_database.dart) |
| 2 | Native-only SQLite dep | [`client/pubspec.yaml`](../../client/pubspec.yaml) — add `drift_flutter` |
| 3 | No web scaffold | Run `flutter config --enable-web`; first `flutter build web` creates `client/web/` |
| 4 | OPFS requires COOP/COEP headers | Preview host `_headers` (Cloudflare Pages format) |

## Acceptance tests (manual on physical iPhone)

Run after **Add to Home Screen** (installed PWA, not Safari tab only).

| ID | Test | Pass criteria |
|----|------|---------------|
| T1 | Cold start offline | Airplane mode ON → launch from home screen → app shell loads (no white screen / endless spinner) |
| T2 | Persist fill-up | Online: create vehicle + one fill-up → close PWA → airplane mode ON → reopen → data still present |
| T3 | Theme toggle | Dark/light switch works offline after T2 |
| T4 | Camera capture (scope) | Capture one image via web camera API; record whether bytes can be stored in OPFS; note Safari version |
| T5 | Storage eviction (optional) | If time permits: document whether OPFS DB survives 24h background — observation only |

## Spike outcomes (fill in when done)

**Verdict:** `GO` | `GO-with-limits` | `NO-GO`

**Date / tester / iOS version:**

**T1–T5 results:**

| ID | Pass/Fail | Notes |
|----|-----------|-------|
| T1 | | |
| T2 | | |
| T3 | | |
| T4 | | |
| T5 | | |

**Photo pipeline decision for iOS PWA:** `full` | `limited` | `deferred`

**Blockers found (if NO-GO):**

**Recommended next engineering steps:**

## References

- Capability matrix: [ADR 005 § iOS PWA capability matrix](adr/005-distribution-channels.md)
- Android distribution (parallel, not blocked by this spike): ADR 005 § Android
