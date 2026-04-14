# Cestovni — product development workflow checklist

**Overall Progress:** ~50% *(Stage 0–1 done; Stage 2a Step 2 accepted (ADR 001); Stage 2b spec **stubs** + Linear children CES-26–32 filed.)*

Update this percentage when a **stage exit** is fully met.

Use this file as the **stage gate** for the Cestovni lifecycle. Each stage has exit criteria; do not skip a stage without an explicit written exception (note the reason in the change log of `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` or in Linear).

**Legend:** 🟩 Done · 🟨 In Progress · 🟥 To Do

---

## TL;DR

We move **baseline → architecture decisions → specs → delivery → launch**. A **spike** is a **short, timeboxed experiment** that answers **one narrow technical question** (e.g. "does on-device ZIP stream acceptably on a mid-range Android in framework X?"). **Backend hosting** and **sync/backup layer** choices are **architecture / ADR work**: discussed, documented, and decided—not buried inside a vague "spike." Optional **mobile client POC** runs only if the team still has material uncertainty after reading ADRs and the brief.

---

## Critical decisions (record in Git)

- **Spike vs architecture:** Spikes prove or disprove a specific uncertainty; architecture items (backend boundary, sync layer) use **ADRs** and normal review.
- **v1 server role:** Cloud **backup/restore** of structured data; **no** server backup of receipt photos (ephemeral, on-device).
- **v1.x direction:** Live multi-device sync when product is ready; spec merge rules before building it.
- **Continuity:** managed-first is acceptable, but we must preserve a **backend-only self-host** continuity path for technical users.
- **Mobile stack:** Chosen after architecture + optional POC; default bias from discovery remains **Flutter + Drift** until ADR/POC says otherwise.

---

## Stage 0 — Repo hygiene & pointers

- 🟩 **Step 0: Canonical docs linked from Linear**
  - 🟩 Project **Cestovni** description points to `docs/product/PRODUCT_BRIEF.md` and this workflow file
  - 🟩 Phase 2 spec + ADR issues include a **Spec:** path (CES-22 children CES-26–32, CES-23–25); spot-check older epics (CES-5–7, CES-9) on next grooming pass

---

## Stage 1 — Product baseline (Phase 1)

- 🟩 **Step 1: Baseline brief locked**
  - 🟩 `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)` reflects north star, v1 scope, and **change log** discipline
  - 🟩 Scope changes use dated **change log** rows (see 2026-04-13 entry)

**Exit:** Brief "Locked" with agreed v1 boundaries.

---

## Stage 2 — Solution shaping: architecture & ADRs (Phase 2a)

Complete **before** treating stack-dependent specs as final.

- 🟩 **Step 2: Backend / API boundary ADR**
  - 🟩 Options compared — **Option C (Hybrid) selected:** `[docs/specs/adr/001-backend-api-boundary.md](../specs/adr/001-backend-api-boundary.md)` (**Accepted**)
  - 🟩 Security model explicit in ADR + RLS/authz test matrix scaffolded in `tests/rls/`
  - 🟩 Deployment matrix documented (managed vs self-host capability table + client contract rules in ADR)
  - 🟩 Runbook executable minimum at `[self-host-runbook.md](../specs/self-host-runbook.md)` with drill checklist
  - 🟩 CI/staging promotion gates scaffolded (`ci/rls-regression.yml`, `ci/promotion-gates.yml`)
  - 🟩 Least-privilege role model documented in ADR + validation tests in `tests/roles/`
  - 🟩 **Exit / portability** notes complete in ADR
  - 🟩 **Accepted** status + Linear **CES-23** closed
- 🟨 **Step 3: Backup / sync layer ADR (v1 + path to v1.x)**
  - 🟨 v1 **backup/restore** direction — **draft:** `[docs/specs/adr/002-backup-sync-layer.md](../specs/adr/002-backup-sync-layer.md)` (**Proposed**)
  - 🟨 Candidates compared (hand-rolled vs PowerSync vs ElectricSQL)
  - 🟥 Full protocol + merge rules in `[sync-protocol.md](../specs/sync-protocol.md)` — **spec pass, not ADR-only**
  - 🟥 **Accepted** + **CES-24** done
- 🟨 **Step 4: Architecture overview doc**
  - 🟨 `[docs/specs/ARCHITECTURE.md](../specs/ARCHITECTURE.md)` draft links ADRs + spec index
  - 🟩 Ephemeral photo pipeline called out
  - 🟥 **CES-25** closed when overview is agreed complete for v1 kickoff
- 🟥 **Step 5 (optional): Mobile client POC — timeboxed**
  - 🟥 **Not started** — run only after ADR review if client-only uncertainty remains (**CES-21**)

### Remaining Stage 2 blockers

- ADR 002 still **Proposed** — must be **Accepted** before Stage 3 stack-bound specs.
- `sync-protocol.md` and `data-model.md` remain **Stubs** — blocked until ADR 001 + 002 accepted.
- Architecture overview (CES-25) needs final alignment pass after both ADRs are accepted.

**Exit:** Backend ADR + sync-layer ADR **Accepted**; architecture doc points to them; optional POC complete or explicitly waived with rationale.

**Alert if skipped:** Starting implementation without **Accepted** ADRs for **server boundary** and **backup/sync mechanism**.

---

## Stage 3 — Technical specs in Git (Phase 2b)

Track as separate Linear issues under **CES-22**; each issue owns one spec file.

- 🟨 **Step 6: Stack-agnostic specs** *(can overlap with Stage 2 if they do not assume server details)*
  - 🟨 Consumption math — stub `[consumption-math.md](../specs/consumption-math.md)`
  - 🟨 SI + US gal — stub `[si-units.md](../specs/si-units.md)`
  - 🟨 Export v1 — stub `[export-v1.md](../specs/export-v1.md)`
  - 🟨 Telemetry — stub `[telemetry-allowlist.md](../specs/telemetry-allowlist.md)`
  - 🟨 Ephemeral photos — stub `[photo-pipeline.md](../specs/photo-pipeline.md)`
- 🟨 **Step 7: Stack-bound specs** *(after Stage 2 exit)*
  - 🟨 Backup/sync protocol — stub `[sync-protocol.md](../specs/sync-protocol.md)` (blocked on **ADR 002**)
  - 🟨 Data model — stub `[data-model.md](../specs/data-model.md)` (blocked on **ADR 001–002**)

**Exit:** Spec files are **complete** (not stubs) and linked from Linear; stack-bound specs match **Accepted** ADRs.

**Alert if skipped:** Implementing DB or sync without finished `sync-protocol` / `data-model` specs.

---

## Stage 4 — Product, legal, store (Phase 2c)

- 🟥 **Step 8: Privacy & compliance posture**
  - 🟨 `[docs/specs/TBD-platform-compliance.md](../specs/TBD-platform-compliance.md)` — outline updated
  - 🟥 Deletion, export, and "photos not backed up" user-visible honesty — **complete**
- 🟥 **Step 9: Launch-facing copy**
  - 🟥 Donations optional; no paywall narrative aligned with brief
  - 🟥 Apple privacy manifest plan (ties to telemetry spec)

**Exit:** Enough to draft store listing and privacy policy with engineering sign-off.

---

## Stage 5 — Delivery (Phase 3)

- 🟥 **Step 10: Engineering breakdown**
  - 🟥 Linear issues per vertical with `**Spec:`** paths
  - 🟥 Estimates and dependencies reflect ADRs (no orphan tasks)
- 🟥 **Step 11: Implementation milestones**
  - 🟥 Local-first app shell → backup → export → remaining v1 scope (order per dependency graph)

**Exit:** Running build with test strategy tied to spec risks (math, backup, export).

---

## Stage 6 — Launch (Phase 4)

- 🟥 **Step 12: Launch criteria & rollback**
  - 🟥 `[docs/specs/TBD-launch.md](../specs/TBD-launch.md)` checklist owned
  - 🟥 Rollback spike (e.g. CES-19) resolved for chosen platform

**Exit:** Ship decision recorded; post-launch ops path clear.

---

## How I'll alert you (process)


| If you try to…                                                             | Stop and fix first                |
| -------------------------------------------------------------------------- | --------------------------------- |
| Pick Flutter/RN without documenting **why** (after optional POC or waiver) | Stage 2 Step 5 note + ADR pointer |
| Implement API or RLS without **Accepted** backend ADR                      | Stage 2 Step 2                    |
| Implement backup without **Accepted** sync-layer ADR                       | Stage 2 Step 3                    |
| Code migrations without **data-model** spec                                | Stage 3 Step 7                    |
| Add telemetry events not on **allow-list**                                 | Stage 3 telemetry spec + PR gate  |


---

## Related

- Baseline: `[PRODUCT_BRIEF.md](PRODUCT_BRIEF.md)`
- Spec folder: `[docs/specs/README.md](../specs/README.md)`
- Linear templates: `[docs/linear/issue-templates.md](../linear/issue-templates.md)`
