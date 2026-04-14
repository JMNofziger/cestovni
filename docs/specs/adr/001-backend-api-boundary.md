# ADR 001: Backend / API boundary (Postgres + auth)

**Status:** Proposed (pending explicit product/engineering sign-off)  
**Date:** 2026-04-13  
**Linear:** CES-23  

## Context

- Product brief: lean server, client-heavy, **structured data backup** in v1; **no** server storage for ephemeral receipt photos.
- Product continuity requirement: managed-first is acceptable, but users should be able to **self-host** if the managed service is unavailable.
- Solo maintainer: minimize undifferentiated ops, keep security boundary **reviewable in Git**.
- Adversarial review: “Supabase or thin API” must become **one** chosen default with an explicit **exit plan**, not an eternal hedge.

## Decision criteria

1. Ship v1 quickly with low operational overhead.
2. Keep data model and auth boundary portable.
3. Keep policy/security reviewable in Git.
4. Preserve a realistic path to self-hosted deployment.

## Options considered

1. **Managed Postgres + PostgREST + RLS** (e.g. Supabase): client talks directly to provider APIs; auth and storage integrated.
2. **Thin HTTPS API + Postgres**: client talks only to app-owned API; auth/session validation and policy checks centralized in server code.
3. **Hybrid (managed-first runtime, app-owned API contract)**: v1 deploys on managed Postgres/Auth, but mobile client targets a stable app-owned API boundary that can run on managed or self-hosted infrastructure.

## Decision (proposed)

**Default for v1:** adopt **Hybrid**.

- Use managed infrastructure in v1 to reduce ops overhead.
- Define an **app-owned backend contract** (endpoints + request/response models) as the long-term boundary; avoid coupling client logic to provider-specific APIs.
- Keep migrations, policies, and schema artifacts in Git, reviewed as code.
- Require parity between managed and self-host deployment modes at the data/auth contract layer.
- v1 direct client access is limited to approved contract surfaces only; no ad hoc provider-specific API usage from product features.

## Rationale

- Meets near-term delivery constraints without locking product semantics to one provider.
- Improves continuity: if hosted service is discontinued, we can ship a self-host package against the same contract.
- Keeps lock-in mitigation explicit and testable instead of aspirational.

## Deployment modes

### Managed mode (v1 default)

- Provider-hosted Postgres/Auth runtime.
- Faster setup and lower operational burden while product is validating.

### Self-host mode (continuity path)

- User/operator runs compatible Postgres + auth/API stack.
- Same schema, migration history, and API contract as managed mode.

## Security model

- **Principals:** authenticated end user, anonymous client (deny by default), CI migration role, backend runtime role, break-glass admin role.
- **Identity model:** authorization keys off stable user identity claims mapped to app-level user identifiers.
- **Boundary rule:** product code may call only app-owned API contract surfaces; provider admin/service interfaces are not reachable from client code.
- **RLS-first authz:** table access is denied by default and allowed only through explicit RLS policies aligned to app ownership and tenancy rules.
- **Provider parity requirement:** managed and self-host modes must enforce the same authn/authz semantics at the contract layer.

## RLS / authorization test matrix (required)

- For each user-scoped table, CI must include:
  - allow: user can read/update only own rows
  - deny: user cannot read/update/delete another user's rows
  - insert checks: `WITH CHECK` prevents cross-user/invalid ownership inserts
  - role checks: non-privileged roles cannot bypass policy intent
- For shared/reference tables, CI must include explicit allow-list behavior (read-only vs no-access).
- Policy tests run on every migration PR and pre-release staging promotion.
- Policy and schema changes are reviewed together; no standalone dashboard policy edits.

## CI / staging promotion gates

- **Migration safety:** migration dry-run against clean DB + representative snapshot.
- **Policy regression:** RLS/authz test matrix must pass in CI and staging.
- **Contract safety:** app-owned API contract tests must pass for managed and self-host modes.
- **Recovery safety:** backup/restore smoke test proves a signed-in user can restore structured data after migration.
- **Release gate:** failing any gate blocks promotion until fixed or explicitly waived in writing by product + engineering.

## Least-privilege controls

- Runtime role has only minimum grants needed for product operations.
- Migration role is separate from runtime role; elevated privileges are time-bound to migration execution.
- Admin/service credentials are never embedded in client binaries or client-accessible config.
- Break-glass access requires explicit incident record and follow-up credential rotation.

## Index and performance guardrails

- Every RLS-protected table must define indexes for ownership/filter columns used by policy predicates and hot-path queries.
- PRs that add/alter policy predicates must include expected query path and index impact note.
- Staging validation includes query-plan spot checks for top backup/restore paths.
- If policy complexity causes unacceptable latency, add targeted server-side endpoint or schema/index changes before launch.

## Exit / portability requirements

- **Data portability:** standard Postgres schema and migrations; no critical proprietary-only SQL features.
- **Auth portability:** stable user identity mapping and claim model documented independent of provider SDK assumptions.
- **API portability:** client depends on app contract, not provider-specific endpoints.
- **Runbook artifacts (minimum):**
  - `docker-compose` baseline for backend stack
  - `.env.example` contract
  - migration + seed commands
  - backup/restore instructions

## Rollback and recovery posture

- Default strategy is forward-fix for policy/config regressions to avoid unsafe drift.
- Destructive migrations require documented rollback path or restore procedure before approval.
- Recovery objective for v1 planning: restore capability must be validated in staging as part of release readiness.
- Backup/restore runbook is a release artifact, not post-launch cleanup.

## Consequences

- Slightly more upfront backend design than direct provider coupling.
- Better long-term survivability and lower re-platforming risk.
- Need discipline: contract tests, migration tests, policy regression tests, and restore drills become mandatory engineering hygiene.

## Acceptance gate (to move Proposed -> Accepted)

- [ ] Deployment matrix documented with explicit capabilities, unsupported scope, and parity constraints for managed vs self-host.
- [ ] Runbook skeleton added at `docs/specs/self-host-runbook.md` covering bootstrap, env contract, migrate/seed, and backup/restore.
- [ ] Contract-locking decisions captured (allowed client surfaces, forbidden direct provider calls, and ownership of contract tests).
- [ ] RLS/authz matrix implemented in CI with evidence links from CES-23 (policy allow/deny + `WITH CHECK` coverage).
- [ ] Least-privilege role model documented and validated (runtime vs migration vs break-glass handling).
- [ ] Staging promotion gate documented with migration dry-run, policy regression, contract, and restore smoke checks.
- [ ] Linked updates in `docs/specs/ARCHITECTURE.md` and `docs/product/PRODUCT_BRIEF.md` change log.

## Open questions

- Final v1 auth provider list (magic link + Apple + Google) and minimal self-host-compatible alternative.
- Whether any server-side endpoint beyond core CRUD is needed in v1 (brief prefers on-device export, so default is no heavy export service).
