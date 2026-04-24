# Senior review packet — UX readiness (2026-04-22)

This packet summarizes the current UX documentation posture for Stage 5 execution and highlights what is approved vs what remains implementation work.

## Scope of this review pass

- UX docs under `docs/product/ux/`
- Product delivery docs referencing UX contracts
- Active Linear delivery issue alignment (focus on CES-39)

## Locked and verified decisions

- Deterministic history ordering is explicit:
  - `event_datetime DESC`, then `created_at DESC`, then `id DESC`
- Maintenance spend in metrics sums `cost_cents` on live events; blank cost in the form persists as `0` per `DATA_CONTRACTS.md` (see also §Metrics contract).
- Date-only maintenance values are local calendar dates (no timezone shift).
- Fill-up quality flags remain visible with helper text:
  - `isFull`, `missedBefore`, `odometerReset`
- Canonical first metrics chart for MVP is **Cost over time**.
- Test-depth policy is **balanced** (happy paths + key edge cases).

## Alignment updates completed in this pass

- Added this packet and linked review artifacts in UX docs.
- Added senior review checklist for repeatable sign-off.
- Codified draft lifecycle in UX behavior + delivery acceptance docs.
- Clarified history delete behavior as soft-delete in v1.
- Wired UX references into delivery planning docs for CES-39.
- Updated CES-39 in Linear:
  - added explicit `UX refs`
  - made photo handling non-blocking for CES-39 and scoped to CES-40

## Document map for reviewers

- UX behavior contract: `docs/product/ux/cestovni-views.md`
- Data semantics contract: `docs/product/ux/DATA_CONTRACTS.md`
- Must-ship gates and tests: `docs/product/ux/DELIVERY_ACCEPTANCE.md`
- Visual system reference: `docs/product/ux/cestovni-styling.md`
- **Implementation gap tracker (blocks CES-39 until closed):** `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`
- Senior checklist: `docs/product/ux/SENIOR_REVIEW_CHECKLIST.md`
- Delivery plan linkage: `docs/product/delivery-plan-v1.md` (M1 prerequisite + CES-39 row)
- Linear: **CES-39** still blocked by **[CES-55](https://linear.app/personal-interests-llc/issue/CES-55)**, **[CES-56](https://linear.app/personal-interests-llc/issue/CES-56)** until each is **Done**; **[CES-53](https://linear.app/personal-interests-llc/issue/CES-53)** and **[CES-54](https://linear.app/personal-interests-llc/issue/CES-54)** are **Done in repo** — set Linear workflow to **Done** and remove stale **blocks** edges if present (see issue comments on CES-39).

## Residual risks (not doc conflicts)

- History, metrics, and maintenance pages are still not implemented; contracts are ready but code work remains.
- Test readiness items in the checklist are intentionally pending until implementation lands.
- Metrics behavior around low-data placeholders is defined but still requires explicit widget/repository coverage in M1/M2 execution.

## Recommended sign-off decision

- **Approve with follow-up issues** (implementation and test execution), not “approve as-is for ship”.
- **CES-39** does not start until every **Open** row under `UX_IMPLEMENTATION_GAPS.md` **Critical gaps** is closed in Linear (today: CES-55, CES-56; CES-53 and CES-54 are **Done** in repo + tracker).
- Use `SENIOR_REVIEW_CHECKLIST.md` as the gate in PR/issue reviews for CES-39 and related UI tickets.
