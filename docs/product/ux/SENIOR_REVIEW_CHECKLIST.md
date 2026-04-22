# Senior review checklist (UX + implementation readiness)

Use this checklist before approving UX-driven implementation work.

## Review metadata

- Review date: 2026-04-22
- Packet: `SENIOR_REVIEW_PACKET.md`
- Reviewer: Product + senior engineer (pending final sign-off)

## 1) Contract alignment

- [x] `cestovni-views.md` matches intended screen behavior for current milestone.
- [x] `DATA_CONTRACTS.md` matches repository field semantics and validation rules.
- [x] `DELIVERY_ACCEPTANCE.md` must-ship scope is realistic for the current release window.

## 2) Locked decisions verification

- [x] History ordering tie-break is explicit and deterministic (`event_datetime`, `created_at`, `id`).
- [x] Maintenance totals rule is explicit (include only rows with date + cost).
- [x] Date-only maintenance handling is explicit (local calendar date, no timezone shift).
- [x] Fill-up quality flags remain visible with helper text (`isFull`, `missedBefore`, `odometerReset`).
- [x] Canonical first metrics chart is fixed to **Cost over time**.
- [x] Test depth is balanced (happy paths + key edge cases).

## 3) Delivery risk scan

- [x] No stale framework references in UX docs (web-only routes/components/libs).
- [x] No open decision placeholders remain in UX docs for current milestone.
- [x] Empty/loading/error states are specified for each in-scope screen.
- [x] Non-goals are explicit to prevent scope creep.

## 4) Test readiness

- [ ] Widget tests cover required-field validation and save success paths.
- [ ] Unit/repository tests cover ordering tie-break, rounding, and totals rules.
- [ ] Edge cases for fill-up flags and low-data metrics placeholders are included.

## 5) Traceability and links

- [x] Active Linear issues reference canonical spec docs.
- [x] UI-heavy issues include UX references under `docs/product/ux/`.
- [x] Product and delivery docs link to UX references where implementers will naturally look.

## 6) Sign-off outcome

- [ ] Approved as-is
- [x] Approved with follow-up issues
- [ ] Changes required before implementation

Reviewer notes:

- Docs and Linear alignment complete for CES-39.
- Implementation/test gates remain open until code and tests land.
