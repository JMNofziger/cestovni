# ADR 001: Backend / API boundary (Postgres + auth)

**Status:** Proposed (pending explicit product/engineering sign-off)  
**Date:** 2026-04-13  
**Linear:** CES-23  

## Context

- Product brief: lean server, client-heavy, **structured data backup** in v1; **no** server storage for ephemeral receipt photos.
- Solo maintainer: minimize undifferentiated ops, keep security boundary **reviewable in Git**.
- Adversarial review: “Supabase or thin API” must become **one** chosen default with an **exit plan**, not an eternal hedge.

## Options considered

1. **Managed Postgres + PostgREST + RLS** (e.g. Supabase): client talks SQL-shaped rows through PostgREST; **authorization in RLS policies** versioned in repo; Auth bundled.
2. **Thin HTTPS API + Postgres**: all writes go through app-owned code; auth session validated in API; **policies in code + tests**; more boilerplate, smaller “declarative blast radius” if you distrust RLS-only.

## Decision (proposed)

**Default for v1:** **Supabase** (Postgres + Supabase Auth + PostgREST) with **every RLS policy and migration in Git** (reviewed like application code), plus a **thin data-access layer in the mobile app** so the UI/domain does not scatter raw PostgREST calls everywhere (eases a future move to a custom API behind the same Postgres schema).

## Rationale

- Fits “boring Postgres,” relational fill-up history, and low ops surface for a small team.
- RLS mistakes are high-severity; **mitigation** = policy tests / staging checks / least privilege, not “trust the dashboard.”

## Exit / portability

- **Data:** standard Postgres dump / replication; avoid proprietary-only features.
- **Auth:** document user identifier mapping and migration steps if leaving Supabase Auth.
- **API shape:** keep domain models in the client aligned with **logical** entities, not PostgREST quirks, to reduce lock-in.

## Consequences

- Must maintain RLS + indexes as first-class artifacts.
- If Supabase pricing or product direction becomes unacceptable, **ADR supersession** + migration plan before large feature build-out on the old path.

## Open questions

- Exact auth providers for v1 (magic link + Apple + Google) and test user story for CI.
- Whether any **server-side** endpoint is required beyond PostgREST (e.g. heavy export)—brief prefers on-device export; assume **none** for v1.
