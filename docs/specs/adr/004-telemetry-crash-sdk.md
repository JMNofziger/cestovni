# ADR 004: Telemetry / crash SDK (Sentry, self-host-capable)

**Status:** Accepted
**Date:** 2026-04-18
**Accepted on:** 2026-04-18
**Linear:** CES-29 (SDK choice deferred by [`telemetry-allowlist.md`](../telemetry-allowlist.md) is now decided)

## Context

- [`telemetry-allowlist.md`](../telemetry-allowlist.md) §"Transport + SDK" listed candidates (Sentry, Firebase Crashlytics, Bugsnag) and required: server-side PII scrub, breadcrumb allow-list, deterministic release tagging, and — **preferred** — a self-hostable or region-pinnable option to satisfy [ADR 001](001-backend-api-boundary.md) continuity.
- [`telemetry-allowlist.md`](../telemetry-allowlist.md) §"Critical gaps / risks" flagged **SDK choice as deferred to implementation (ADR follow-up)**. Stage 5 is that moment; Milestone 4 ("Telemetry client wiring" in [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md)) is blocked without this ADR.
- Client stack is **Flutter + Drift** per [ADR 003](003-mobile-stack.md); the chosen SDK must have a maintained Dart/Flutter package.

## Decision criteria

1. **Server-side PII scrub** configurable (URL, IP, body) without client-side changes.
2. **Breadcrumb control** strong enough to enforce the allow-list in [`telemetry-allowlist.md`](../telemetry-allowlist.md) §"Breadcrumb allow-list."
3. **Deterministic release tagging** (so crashes map to Git SHAs).
4. **Self-host-capable** — continuity per ADR 001.
5. **First-class Flutter SDK** — ADR 003.
6. **Apple `PrivacyInfo.xcprivacy` + Play Data Safety** mapping documentable from vendor's own compliance data ([`platform-compliance-v1.md`](../platform-compliance-v1.md) §8).

## Options considered

1. **Sentry (sentry_flutter)** — open-source server; self-hosted or SaaS; Dart/Flutter package maintained by Sentry; scrubbing via `beforeSend` + project settings; region pinning available on SaaS.
2. **Firebase Crashlytics** — strong Flutter support; **no self-host path**; ties crash pipeline to Google — fails criterion 4.
3. **Bugsnag** — maintained Flutter SDK; SaaS-only for practical purposes; fails criterion 4.

## Decision

**Adopt Sentry (self-host-capable)** for crash reporting and allow-listed product events in v1.

- Transport for product events uses Sentry's event API (no third-party product-analytics SDKs — brief principle, reaffirmed in [`telemetry-allowlist.md`](../telemetry-allowlist.md)).
- v1 can start on Sentry SaaS (region-pinned) to reduce ops; the self-host path stays documented so continuity mirrors [ADR 001](001-backend-api-boundary.md).
- Scrub configuration lives in the infra repo, **not** the mobile client — per telemetry spec §"Transport + SDK."

## Implementation constraints (wired into Milestone 4)

- **`beforeSend` hook** filters every payload through the emit-function allow-list before any network call (defense in depth with the compile-time `ci/telemetry-gate.*`).
- **Release tag** set to the Flutter build's Git SHA at build time.
- **User identity** is the pepper-HMAC of the raw user id, never the raw id — [`telemetry-allowlist.md`](../telemetry-allowlist.md) §"Principles" (3).
- **Breadcrumbs** constrained per spec — disable auto-navigation breadcrumbs that would leak VIN / notes / filenames.
- **Pepper lifecycle** owned by [`platform-compliance-v1.md`](../platform-compliance-v1.md) §5.3; SDK does not own it.

## Consequences

- **Positive:** Sentry OSS gives us a working continuity story; Dart SDK matches the client choice; one SDK for crashes + allow-listed events reduces surface area.
- **Negative:** Sentry's default breadcrumbs are broader than our allow-list — M4 must explicitly disable categories the spec forbids; that work is not optional.
- **Risk:** self-host migration isn't free if we start on SaaS. Mitigation: keep configuration declarative and version-controlled so lift-and-shift is straightforward.

## Non-goals

- Behavioral product analytics or funnel tooling.
- Per-screen instrumentation beyond what's in [`telemetry-events.v1.yaml`](../telemetry-events.v1.yaml).
- Any SDK that would require expanding the allow-list without PR review.

## Revisit gates

- Sentry changes licensing or self-host terms in a way that breaks continuity.
- `beforeSend` or breadcrumb controls regress in the Flutter SDK.
- Store platforms require a scrub/disclosure we cannot produce with this vendor.

## Related

- [`telemetry-allowlist.md`](../telemetry-allowlist.md) — principles, allow-list, CI gate.
- [`telemetry-events.v1.yaml`](../telemetry-events.v1.yaml) — authoritative catalogue.
- [`platform-compliance-v1.md`](../platform-compliance-v1.md) §5.3, §7, §8 — retention, third-party disclosure, store mapping.
- [ADR 001](001-backend-api-boundary.md) — continuity requirement.
- [ADR 003](003-mobile-stack.md) — Flutter constraint on SDK availability.
- [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md) — Milestone 4 depends on this ADR.
