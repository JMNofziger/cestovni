# Cestovni — product development workflow checklist

**Overall Progress:** ~95% *(Stages 0–4 closed: Stage 4 engineering sign-off recorded 2026-04-17 in `platform-compliance-v1.md` §11; product ack on launch copy; Stage 5 Delivery / engineering breakdown is next. Residual compliance work — `ci/telemetry-gate.`*, Apple/Play submission-time forms, external counsel privacy policy — tracked as Stage 5 / launch follow-ups, not Stage 4 blockers.)*

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
  - 🟩 Project **Cestovni** description points to GitHub **main** ([repo](https://github.com/JMNofziger/cestovni), [README](https://github.com/JMNofziger/cestovni/blob/main/README.md), [brief](https://github.com/JMNofziger/cestovni/blob/main/docs/product/PRODUCT_BRIEF.md), [this workflow](https://github.com/JMNofziger/cestovni/blob/main/docs/product/PRODUCT_DEV_WORKFLOW.md))
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
- 🟩 **Step 3: Backup / sync layer ADR (v1 + path to v1.x)**
  - 🟩 v1 **backup/restore** direction — **hand-rolled outbox** selected: `[docs/specs/adr/002-backup-sync-layer.md](../specs/adr/002-backup-sync-layer.md)` (**Accepted** 2026-04-17)
  - 🟩 Candidates compared (hand-rolled vs PowerSync vs ElectricSQL); managed sync runtimes deferred to an explicit v1.x revisit gate in ADR 002
  - 🟩 Protocol primitives (server `row_version` sequence, per-table cursor, idempotent mutations, cursor-paginated restore) frozen in ADR 002 + `[sync-protocol.md](../specs/sync-protocol.md)` **spec pass 1**; v1.x field-level merge rules remain a roadmap pointer
  - 🟩 **Accepted** + **CES-24** ready to close
- 🟩 **Step 4: Architecture overview doc**
  - 🟩 `[docs/specs/ARCHITECTURE.md](../specs/ARCHITECTURE.md)` links both **Accepted** ADRs and the sync-protocol spec
  - 🟩 Ephemeral photo pipeline called out (+ link to `photo-pipeline.md`)
  - 🟩 **CES-25** closed — product sign-off for v1 kickoff (2026-04-17)
- 🟩 **Step 5 (optional): Mobile client POC — timeboxed**
  - 🟩 **Waived (2026-04-17)** — no material client-only uncertainty after Accepted ADRs 001/002 + `sync-protocol.md` spec pass 1; stack follows brief default bias until delivery chooses otherwise. Rationale on **CES-21**.

### Remaining Stage 2 blockers

- None. Stage 2 exit fully met; Stage 3 completed on 2026-04-17 — see the Stage 3 section below for each spec's status.

**Exit:** Backend ADR + sync-layer ADR **Accepted**; architecture doc points to them; optional POC complete or explicitly waived with rationale.

**Alert if skipped:** Starting implementation without **Accepted** ADRs for **server boundary** and **backup/sync mechanism**.

---

## Stage 3 — Technical specs in Git (Phase 2b)

Track as separate Linear issues under **CES-22**; each issue owns one spec file.

- 🟩 **Step 6: Stack-agnostic specs** *(can overlap with Stage 2 if they do not assume server details)*
  - 🟩 Consumption math — `[consumption-math.md](../specs/consumption-math.md)` **Complete (v1)** — segment model, integer formulas, 8 golden-test fixtures (**CES-26**)
  - 🟩 SI + US gal — `[si-units.md](../specs/si-units.md)` **Complete (v1)** — INT64 µL / m / cents; exact conversions; banker's rounding (**CES-27**)
  - 🟩 Export v1 — `[export-v1.md](../specs/export-v1.md)` **Complete (v1)** — ZIP layout, manifest.json, CSV contract, streaming assembly (**CES-28**)
  - 🟩 Telemetry — `[telemetry-allowlist.md](../specs/telemetry-allowlist.md)` **Complete (v1)** — + machine-readable `[telemetry-events.v1.yaml](../specs/telemetry-events.v1.yaml)` (**CES-29**)
  - 🟩 Ephemeral photos — `[photo-pipeline.md](../specs/photo-pipeline.md)` **Complete (v1)** — EXIF strip, TTL rules, no server backup (**CES-30**)
- 🟩 **Step 7: Stack-bound specs** *(after Stage 2 exit)*
  - 🟩 Backup/sync protocol — `[sync-protocol.md](../specs/sync-protocol.md)` **Complete for v1** — batch caps, 429 semantics, dead-letter UX, table names aligned with data-model (**CES-31**); v1.x merge-rule pass explicitly deferred per ADR 002
  - 🟩 Data model — `[data-model.md](../specs/data-model.md)` **Complete (v1)** — tables, SI-integer columns, protocol columns, indexing, RLS shape, migration alignment (**CES-32**)

**Exit:** Spec files are **complete** (not stubs) and linked from Linear; stack-bound specs match **Accepted** ADRs.

**Alert if skipped:** Implementing DB or sync without finished `sync-protocol` / `data-model` specs.

---

## Stage 4 — Product, legal, store (Phase 2c)

- 🟩 **Step 8: Privacy & compliance posture**
  - 🟩 `[platform-compliance-v1.md](../specs/platform-compliance-v1.md)` — **Complete (v1)** — data inventory, deletion / export / telemetry erasure, user-visible honesty, third parties, Apple + Play disclosure mapping, residency + minors v1 position (**CES-8**)
  - 🟩 Deletion, export, and “photos not backed up” user-visible honesty — **complete** (see spec §§3–5)
- 🟩 **Step 9: Launch-facing copy**
  - 🟩 `[launch-copy-v1.md](launch-copy-v1.md)` — store listing draft, privacy policy H2 outline, in-app Data & privacy bullets, donations optional / no paywall phrasing
  - 🟩 Apple privacy manifest plan — normative categories in `[telemetry-allowlist.md](../specs/telemetry-allowlist.md)`; ownership + Play mapping in `platform-compliance-v1.md` §8; `**ci/telemetry-gate.`* implementation** deferred to Stage 5 per telemetry spec

**Exit:** Met and **signed off (2026-04-17)** — engineering checklist in `[platform-compliance-v1.md` §11](../specs/platform-compliance-v1.md#11-engineering-sign-off-checklist-stage-4-exit) ticked; product ack on `[launch-copy-v1.md](launch-copy-v1.md)`; counsel handoff section in launch copy §10 lists the package for external review.

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

