# ADR 003: Mobile client stack (Flutter + Drift)

**Status:** Accepted
**Date:** 2026-04-18
**Accepted on:** 2026-04-18
**Linear:** CES-21 (Stage 2 Step 5 was waived — stack choice formalized here at Stage 5 kickoff)

## Context

- [`PRODUCT_DEV_WORKFLOW.md`](../../product/PRODUCT_DEV_WORKFLOW.md) L21–24 records a default **bias** toward **Flutter + Drift** but says the choice must be "chosen after architecture + optional POC."
- Stage 2 Step 5 (mobile POC) was **waived (2026-04-17)** — no material client-only uncertainty remained after [ADR 001](001-backend-api-boundary.md), [ADR 002](002-backup-sync-layer.md), and [`sync-protocol.md`](../sync-protocol.md) spec pass 1.
- Stage 5 (delivery) cannot start without a recorded stack: Milestone 1 ("Mobile client bootstrap" in [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md)) needs a concrete framework to scaffold.

## Decision criteria

1. **Offline-first SQLite ergonomics.** Client persistence is the source of truth per [ADR 002](002-backup-sync-layer.md); we need a typed DAO with good migration tooling.
2. **Single codebase → iOS + Android** for solo-maintainer delivery speed (brief principles).
3. **File / camera access sufficient for the photo pipeline.** EXIF strip + sandbox write per [`photo-pipeline.md`](../photo-pipeline.md) must be practical without shell-outs to native plugins we own.
4. **Packaging for App Store + Play** with a realistic privacy manifest story (Apple `PrivacyInfo.xcprivacy`, Play Data Safety) per [`platform-compliance-v1.md`](../platform-compliance-v1.md).
5. **Portability** — avoiding a stack we'd be embarrassed to replace in 18 months.

## Options considered

1. **Flutter + Drift** (default bias) — Dart, single codebase, Drift provides typed SQLite with first-party migration helpers.
2. **React Native + SQLite (e.g. op-sqlite or expo-sqlite) + TypeScript ORM** — larger ecosystem; more moving parts on the SQLite side.
3. **Native twin (Swift + Kotlin with shared C++/Rust core)** — highest fidelity, highest ongoing cost; wrong shape for solo maintenance in v1.

## Decision

**Adopt Flutter + Drift for v1.** The mobile client is Flutter; Drift is the SQLite layer for structured data.

Why (short form):

- Drift's codegen and `MigrationStrategy` hooks map cleanly to our INT64 µL / m / cents columns in [`data-model.md`](../data-model.md) without leaking types through a generic ORM.
- Flutter's platform channels cover camera + filesystem needs for [`photo-pipeline.md`](../photo-pipeline.md) with well-maintained first-party packages; no exotic native plugins required in v1.
- One codebase → iOS + Android keeps solo-maintainer delivery realistic for v1 scope.
- Packaging + privacy manifest workflows are well-trodden on Flutter; no surprises expected in the submission phase.

## Consequences

- **Positive:** fewer moving parts in persistence; typed DAOs reduce the odds of storing a DECIMAL/FLOAT where INT64 is canonical (brief locked decision).
- **Negative:** Dart ecosystem is narrower than TS; some SDKs (crash/telemetry per [ADR 004](004-telemetry-crash-sdk.md)) must be selected against Dart availability and server-side PII scrub support.
- **Portability:** the app-owned API contract in [ADR 001](001-backend-api-boundary.md) is framework-agnostic; a future re-platform swaps clients without touching the server boundary.

## Non-goals

- Desktop or web targets in v1.
- Custom rendering / 3D.
- Shared business-logic core in Rust/C++ (reconsider only if a second client is green-lit).

## Revisit gates (when to re-open this ADR)

- Drift or a critical Flutter plugin loses maintenance without a credible fork.
- Privacy-manifest tooling on Flutter falls meaningfully behind RN/native at store-submission time.
- The product takes on a second client (watch / web) where a shared TS core would materially reduce duplication.

## Exit / portability

- **Data:** all user data is portable via [`export-v1.md`](../export-v1.md) ZIP regardless of client choice.
- **Protocol:** replacing the client does not require server changes — contract is in [ADR 001](001-backend-api-boundary.md).
- **Schema:** [`data-model.md`](../data-model.md) canonical columns are framework-independent; Drift is a typed façade, not a schema authority.

## Implementation reference (Stage 5)

- **2026-04-18:** Repository includes the **Flutter + Drift** client under [`client/`](../../../client/) (nav shell, Drift `AppDatabase`, v1 schema per `data-model.md`). Tracked on Linear as **CES-36** (bootstrap) and **CES-37** (client DB); see [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md) for milestone status.

## Related

- [`PRODUCT_DEV_WORKFLOW.md`](../../product/PRODUCT_DEV_WORKFLOW.md) — stage gates.
- [`../../product/delivery-plan-v1.md`](../../product/delivery-plan-v1.md) — M0 bootstrap depends on this ADR.
- [`data-model.md`](../data-model.md), [`photo-pipeline.md`](../photo-pipeline.md), [`sync-protocol.md`](../sync-protocol.md) — specs this ADR unblocks.
