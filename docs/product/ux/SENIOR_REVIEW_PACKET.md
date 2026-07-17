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
- **Implementation gap tracker (gate closed; CES-39 Done):** `docs/product/ux/UX_IMPLEMENTATION_GAPS.md`
- Senior checklist: `docs/product/ux/SENIOR_REVIEW_CHECKLIST.md`
- Delivery plan linkage: `docs/product/delivery-plan-v1.md` (M1 prerequisite + CES-39 row)
- Linear: **CES-39** gate is clear in repo — **[CES-53](https://linear.app/personal-interests-llc/issue/CES-53)**, **[CES-54](https://linear.app/personal-interests-llc/issue/CES-54)**, **[CES-55](https://linear.app/personal-interests-llc/issue/CES-55)**, and **[CES-56](https://linear.app/personal-interests-llc/issue/CES-56)** are **Done in repo**. Set each Linear workflow to **Done** and remove stale **blocks** edges if present (see issue comments on CES-39).

## Residual risks (not doc conflicts)

- **Metrics** and **Maint** tab UI still stubs → **[CES-66](https://linear.app/personal-interests-llc/issue/CES-66)** / **[CES-67](https://linear.app/personal-interests-llc/issue/CES-67)**; History is fuel-only until maintenance repo lands.
- **CES-57 shipped** (PR #9). **Follow-on:** Log/History prefs display → **[CES-65](https://linear.app/personal-interests-llc/issue/CES-65)**.
- Metrics low-data placeholder behavior still needs widget/repository coverage when Metrics tab ships.

## Recommended sign-off decision

- **Approve with follow-up issues** for remaining M1 surfaces (Metrics, Maint, photo, Log/History prefs display).
- **CES-39** prerequisite gate is **closed in repo**; align Linear blocks-CES-39 edges.
- Use `SENIOR_REVIEW_CHECKLIST.md` for CES-39 PR reviews; track rollup in `delivery-plan-v1.md` RYG.
