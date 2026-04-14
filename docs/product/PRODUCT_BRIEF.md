# Cestovni — product brief (baseline)

**Status:** Locked baseline — **2026-04-06**. Further product scope changes use a **change log** entry at the bottom of this file.

**Canonical copy lives in Git:** this file — use this path in Linear, PRs, and handoffs.

## Product principles

- **Primary goal:** **Best possible experience for the user** — not revenue, not engagement-for-its-own-sake.
- **Monetization:** **Not a goal.** No ads, no paywalls on core use. **Donations/tips** are **optional gratitude only** — the product must remain **fully usable and maintainable with zero expectation of user payments.**
- **Sustainability:** Viability through **lean architecture** (client-heavy, efficient sync/media, minimal server surface) and **operator cost discipline** — **not** through funding from users.
- **Continuity / self-hosting:** Managed-first delivery is acceptable, but backend architecture must preserve a realistic path for **technical users** to self-host core backend services if the managed service is no longer available.
- **Telemetry:** **Minimal**, only for **reliability, debugging, and honest product improvement** (e.g. crashes, sync failures, core funnel to find broken flows). **No** behavioral surplus for ads, **no** third-party monetization of user data, **no** growth-hacking stacks unless explicitly decided later.

## Locked decisions


| Area              | Choice                                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------------------ |
| Platform          | Cross-platform mobile (one codebase); stack chosen in **Phase 2** via **architecture + optional client POC** (see [`PRODUCT_DEV_WORKFLOW.md`](PRODUCT_DEV_WORKFLOW.md)) |
| Offline           | Open app + **log fill-up with zero network**; **v1** = cloud **backup/restore** of structured data when signed in; **v1.x** = live multi-device sync (spec’d separately) |
| Photos            | **Ephemeral on-device** aids for deferred entry (e.g. receipt snap → complete later); **short TTL** (target **30 days**); **not** backed up to server; **not** in ZIP export |
| OCR               | Manual entry + photos + queue; **OCR Phase 2+**                                                              |
| Units             | **SI canonical** in storage; user **mi/km** + **gal/L** display/entry; **US liquid gallon** when gal is used |
| Export            | **ZIP**: per-entity **CSVs** + `README_export.txt` + `manifest.json`; prefer **on-device** assembly          |
| Insights          | **No** fuel-quality insight **product** in v1; optional notes only; **Phase 2+**                             |
| Commercial        | **Free**; **donations optional**, never required for sustainability narrative or feature access              |
| Architecture bias | Client-heavy; efficient images; **minimal ethical telemetry**; user pays own bandwidth on bulk export        |
| Deployment continuity | **Managed-first** operation is allowed; architecture must support **backend-only self-host** continuity for technical users |


## North star

Trustworthy fuel + maintenance history, **offline-safe logging**, full **data portability**, credible long-run economy and TCO — **without lock-in**.

## v1 scope (must ship)

- Multi-vehicle; sold/archive; VIN/tire/wheel fields (UX spec)
- Fill-ups: partial/full, missed-fill handling, consumption math + tests, hero economy + trends + price history
- Maintenance: recurring + one-off; archive on complete; estimates; dashboard vs simple list
- Photos: **local** attach + queue for deferred completion; **no** server photo backup in v1; no OCR requirement
- **Backup** when online (structured data); staged restore/hydration (logging never blocked on full download). **Live sync** is v1.x unless promoted by explicit scope change
- Export: ZIP bundle as locked
- Themes: light / dark / system

## v1 out of scope

Structured fuel-quality insights; OCR; fleet B2B; ads; paywalled core features.

## Risks (require specs/tests)

1. **Consumption math** — golden tests.
2. **Offline sync / conflicts** — merge rules; export if mid-sync.
3. **Export at scale** — chunk/stream; on-device vs server (spec).
4. **Rounding** — charts vs CSV; README.

## Linear epics (reference)


| Epic theme            | Focus                                                                   |
| --------------------- | ----------------------------------------------------------------------- |
| Problem & users       | ICP, v1 boundary                                                        |
| Core journeys         | Fill-up, charts, maintenance, export, vehicles                          |
| Platform & compliance | Auth, sync, SI schema, media, export, GDPR/delete                       |
| Analytics & ops       | Crash + reliability signals; operator cost — not monetization analytics |
| Launch                | Privacy (export, sync, photos); donations = optional copy               |


## Planning phases


| Phase                    | What                                                                                                           | Status        |
| ------------------------ | -------------------------------------------------------------------------------------------------------------- | ------------- |
| **1 — Product brief**    | This document                                                                                                  | **Locked**    |
| **2 — Solution + specs** | **Architecture ADRs** (backend boundary, backup/sync layer) → **architecture note** → Git specs (consumption, backup/sync, export, SI, **ephemeral photos**, telemetry allow-list); **optional** timeboxed **client POC** if needed — see [`PRODUCT_DEV_WORKFLOW.md`](PRODUCT_DEV_WORKFLOW.md) | Next          |
| **3 — Delivery**         | Linear breakdown, estimates, link `docs/specs/...`                                                             | After Phase 2 |


**Order:** **Backend + sync-layer ADRs** first (not a “spike”); **stack-agnostic** specs (e.g. consumption math, export, telemetry) may run **in parallel**. **Stack-dependent** specs (data model, backup protocol details) finalize after ADRs. **Optional** timeboxed **client POC** (Flutter vs RN/KMP) only for residual uncertainty — see workflow doc.

## Phase 2 checklist (engineering)

1. Architecture: ADRs or equivalent for **backend/API boundary** and **backup/sync layer** (v1 backup + v1.x path); `docs/specs/ARCHITECTURE.md` (or ADR index) linking to them.
2. Continuity: ADR 001 must include deployment matrix (**managed vs self-host**) and a tracked backend-only self-host runbook skeleton.
3. Optional: timeboxed **client POC** with pre-written pass/fail criteria (offline SQLite, camera, **backup job enqueue**, on-device export) — **only if** needed after ADRs.
4. Specs in `docs/specs/`: consumption/fill-up; **backup + v1.x sync**; export v1; SI + US gal; **ephemeral photo / deferred entry**; telemetry allow-list.
5. Legal / store: privacy, deletion, donation copy (photos not server-backed, export scope).
6. Linear: granular issues + spec links; follow [`PRODUCT_DEV_WORKFLOW.md`](PRODUCT_DEV_WORKFLOW.md) stage gates.

---

## Change log


| Date       | Change                                             |
| ---------- | -------------------------------------------------- |
| 2026-04-06 | Baseline locked — initial brief from PM discovery. |
| 2026-04-13 | **Clarifications:** v1 **backup/restore** vs **v1.x live sync**; **ephemeral local photos** (TTL, no server backup, not in export); Phase 2 workflow — **ADRs** for backend + sync layer; **spike** = optional narrow client POC only. See [`PRODUCT_DEV_WORKFLOW.md`](PRODUCT_DEV_WORKFLOW.md). |
| 2026-04-13 | **Engineering:** Draft **ADRs** in `docs/specs/adr/` (001 backend, 002 backup/sync); `docs/specs/ARCHITECTURE.md` + **spec stubs**; Linear **CES-26–CES-32** under **CES-22** (one issue per spec). ADR status **Proposed** until explicitly accepted. |
| 2026-04-14 | **Continuity update:** self-hosting requirement clarified — managed-first is acceptable, but architecture must preserve **backend-only self-host** continuity for technical users. ADR 001 acceptance gate updated accordingly. |
| 2026-04-14 | **Risk hardening:** ADR 001 expanded with explicit security model, RLS/authz CI matrix, least-privilege controls, index/performance guardrails, and staging promotion gates (including restore smoke checks) before acceptance. |
