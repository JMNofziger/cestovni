# ADR 001 addendum: self-host hosting recommendation

**Status:** Accepted
**Date:** 2026-07-22
**Parent:** [ADR 001 — Backend / API boundary](001-backend-api-boundary.md)
**Runbook:** [`../self-host-runbook.md`](../self-host-runbook.md)
**Linear:** [CES-69](https://linear.app/personal-interests-llc/issue/CES-69) (Done)

## Context

[ADR 001](001-backend-api-boundary.md) requires a realistic **backend-only self-host continuity path**, and [`self-host-runbook.md`](../self-host-runbook.md) already documents the mechanics (`docker compose up -d`, operator-hosted Postgres 15+). What was missing is a concrete answer to "**where do I actually run this, for free (or close to it)?**"

Product expectation: self-hosting is not a rare fallback — it is the **primary deployment mode for cost-conscious users**. Sizing input: a single user's history is small — roughly **1000 fill-ups/year**. Even with protocol columns and indexes ([`data-model.md`](../data-model.md)), that is on the order of a few hundred KB/year; a decade of history is still single-digit MB. **Every option below has 100-1000x that in free storage.** The real constraints are uptime predictability and staying on standard Postgres (no proprietary lock-in), not capacity.

## Decision criteria

1. **Cost ceiling:** $0/year preferred; up to **~$24/year** acceptable if it buys real, durable self-host independence (own Postgres instance, not a third-party API).
2. **Standard Postgres only** — no proprietary extensions required, per [ADR 001 exit/portability requirements](001-backend-api-boundary.md#exit--portability-requirements).
3. **Matches the documented runbook** — the operator runs the existing `docker compose` stack themselves; we are not introducing a new deployment mechanism.
4. **Durability of the "free" promise** is a risk to name explicitly, not assume.

## Options considered

| Option | Cost | Fit |
|---|---|---|
| **Oracle Cloud "Always Free" VM** (own Postgres via compose) | **$0/yr** | Real self-host: operator's own VM, own Postgres 15+, standard image. Best fit. |
| Third-party free-tier Postgres DBaaS (Aiven, Neon, Supabase, Render) | $0/yr | Standard Postgres connection string, but reintroduces a third-party dependency — the operator does not control the instance. Undermines the "real independence" goal; each also carries a caveat (Aiven powers off on inactivity; Neon caps compute hours; Render free DB expires after 30 days). Fine as a **managed-mode** option for non-technical users later, not the self-host recommendation. |
| Cheapest reputable always-on VPS (Hetzner CX line) | ~**$48-50/yr** in 2026 | Full independence, most predictable, but no mainstream reputable always-on VPS currently clears the $24/yr ceiling — this is the paid fallback, not the primary pick. |

## Decision

**Recommend Oracle Cloud Infrastructure (OCI) "Always Free" tier** as the primary self-host target, running the existing `docker compose` stack from [`self-host-runbook.md`](../self-host-runbook.md) unmodified:

- **Primary shape:** `VM.Standard.E2.1.Micro` (AMD, 1 GB RAM) — smaller, simpler resource ask, least likely to be affected by future allocation cuts.
- **Alternative shape:** `VM.Standard.A1.Flex` (Ampere/Arm) — currently 2 OCPU / 12 GB always-free allocation (reduced from 4 OCPU / 24 GB in a June 2026 change); still enormous headroom for a 1000-fill-up/year dataset, but a larger, more attractive allocation that is more exposed to future reductions.
- **200 GB Always Free block storage** covers the Postgres data volume for the practical lifetime of the product.
- Both shapes run standard Ubuntu/Oracle Linux images; installing Postgres and running `docker compose up -d` from the runbook requires **no changes to the documented process**.

**Named fallback:** if Oracle changes Always Free terms again (see risk below) and an operator wants a paid, more predictable alternative, recommend a small Hetzner CX-series VPS (~$48-50/year at 2026 pricing) — still well under most cloud budgets, and the same `docker compose` stack moves over as a data-directory copy, not a rewrite.

**Not recommended for the self-host persona (v1):** third-party free-tier DBaaS. They are a reasonable option to keep in mind for a future non-technical **managed-mode** hosting choice, but not for the "real self-host independence" use case this addendum targets.

## Rationale

- The dataset size makes storage/compute capacity a non-issue on every option; the decision is driven entirely by independence and durability of the free promise.
- Oracle Always Free is the only option that gives the operator their **own** Postgres instance (not a shared multi-tenant DBaaS) at $0, matching the self-host runbook's existing design exactly.
- The June 2026 Ampere allocation cut (documented below) is real evidence that "free forever" claims can change; the mitigation is architectural (standard Postgres + compose = portable), not a promise about any one vendor.

## Risk: Oracle Always Free is not contractually permanent

- On **2026-06-15**, Oracle silently reduced the Always Free Ampere A1 allocation from 4 OCPU/24 GB to 2 OCPU/12 GB, with no blog post, customer notification, or changelog entry — operators discovered it when instances were shut down or via community reports.
- **Mitigation:** this addendum recommends the smaller, simpler AMD Micro shape as primary (less attractive to cut further) and treats Oracle Always Free as "best-effort $0," not a guaranteed SLA. The runbook's portability (standard Postgres, docker-compose, `pg_dump`/`pg_restore`) is what actually protects continuity — moving to the named Hetzner fallback is a data copy, not a re-architecture.
- Operators should set a calendar reminder to re-check Oracle's Always Free page periodically, and should not rely on out-of-band notification of future changes.

## Consequences

- **Positive:** closes the vague "Managed free tier or self-host" cost placeholder in [ADR 005 — cost table](005-distribution-channels.md#cost-table-stage-1-target) with a real, actionable recommendation at $0/year.
- **Positive:** no change to the runbook's mechanics — this is a hosting-target recommendation, not a new deployment path.
- **Negative:** Oracle Always Free is not contractually guaranteed to stay at current limits (already changed once in 2026); operators must accept some best-effort risk at the $0 tier.
- **Neutral:** managed mode (v1 default) is unaffected by this addendum — it is scoped to the self-host continuity path only.

## Related

- [ADR 001 — Backend / API boundary](001-backend-api-boundary.md) — deployment matrix, exit/portability requirements.
- [`self-host-runbook.md`](../self-host-runbook.md) — bootstrap/migrate/backup/restore mechanics this addendum targets.
- [ADR 005 — Distribution channels](005-distribution-channels.md) — Stage 1 cost table, updated to point here.
