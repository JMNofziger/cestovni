# ADR 004 addendum: Glitchtip as crash/telemetry transport (Stage 1)

**Status:** Accepted
**Date:** 2026-05-17
**Parent:** [ADR 004 — Telemetry / crash SDK](004-telemetry-crash-sdk.md)
**Linear:** CES-46 (M4 client wiring)

## Context

ADR 004 adopted **`sentry_flutter`** as the **client SDK** and Sentry's event API as the **transport shape** for allow-listed reliability events. The open question at implementation time was **where events land**: Sentry SaaS, full **Sentry OSS self-host**, or a lighter compatible backend.

Full Sentry OSS self-host requires Postgres, Redis, Kafka, Clickhouse, and multiple workers (~8GB+ RAM) — poor fit for Stage 1 **~$0 recurring** ops alongside a lean backup API.

## Decision

**Stage 1 transport: [Glitchtip](https://glitchtip.com)** (self-hosted when M3 infra exists).

- **Client:** unchanged — continue with **`sentry_flutter`** and a project DSN pointing at the Glitchtip instance.
- **Server:** Glitchtip (Sentry-API-compatible OSS) in Docker + Postgres (~1GB RAM); can co-locate on the same VPS as self-host backup API per [ADR 001](001-backend-api-boundary.md).
- **Earliest betas (pre-infra):** Sentry SaaS **free tier** (5K errors/month) is acceptable temporarily; DSN env var only — no client code fork.

Glitchtip satisfies ADR 004 criterion **self-host-capable** without operating the full Sentry OSS stack.

## Implementation notes (CES-46)

- `SENTRY_DSN` (or equivalent) build-time / runtime env points to Glitchtip or SaaS free tier.
- All [ADR 004](004-telemetry-crash-sdk.md) constraints still apply: `beforeSend` allow-list filter, release = Git SHA, pepper-HMAC user key, breadcrumb restrictions per [`telemetry-allowlist.md`](../telemetry-allowlist.md).
- [`platform-compliance-v1.md`](../platform-compliance-v1.md) §7 third-party disclosure: name **Glitchtip** (self-hosted) in privacy copy when wired; not "Sentry cloud" unless SaaS free tier is active.
- `ci/telemetry-gate.py` check 4 (Apple `PrivacyInfo.xcprivacy`) remains **skipped** while App Store is deferred ([ADR 005](005-distribution-channels.md)).

## Fallback

If Glitchtip maintenance or licensing becomes unacceptable: switch DSN to **Sentry SaaS free tier** or document migration to full Sentry OSS in a superseding addendum. Client SDK and allow-list do not change.

## Related

- [ADR 005](005-distribution-channels.md) — distribution and cost posture.
- [`self-host-runbook.md`](../self-host-runbook.md) — add Glitchtip service when M3 runbook is implemented.
