# Cestovni — product brief (baseline)

**Status:** Locked baseline — **2026-04-06**. Further product scope changes use a **change log** entry at the bottom of this file.

**Canonical copy lives in Git:** this file — use this path in Linear, PRs, and handoffs.

## Product principles

- **Primary goal:** **Best possible experience for the user** — not revenue, not engagement-for-its-own-sake.
- **Monetization:** **Not a goal.** No ads, no paywalls on core use. **Donations/tips** are **optional gratitude only** — the product must remain **fully usable and maintainable with zero expectation of user payments.**
- **Sustainability:** Viability through **lean architecture** (client-heavy, efficient sync/media, minimal server surface) and **operator cost discipline** — **not** through funding from users.
- **Telemetry:** **Minimal**, only for **reliability, debugging, and honest product improvement** (e.g. crashes, sync failures, core funnel to find broken flows). **No** behavioral surplus for ads, **no** third-party monetization of user data, **no** growth-hacking stacks unless explicitly decided later.

## Locked decisions

| Area | Choice |
|------|--------|
| Platform | Cross-platform mobile (one codebase); **Flutter vs RN (etc.)** = **Phase 2 stack spike** |
| Offline | Open app + **log fill-up with zero network**; sync is additive |
| OCR | Manual entry + photos + queue; **OCR Phase 2+** |
| Units | **SI canonical** in storage; user **mi/km** + **gal/L** display/entry; **US liquid gallon** when gal is used |
| Export | **ZIP**: per-entity **CSVs** + `README_export.txt` + `manifest.json`; prefer **on-device** assembly |
| Insights | **No** fuel-quality insight **product** in v1; optional notes only; **Phase 2+** |
| Commercial | **Free**; **donations optional**, never required for sustainability narrative or feature access |
| Architecture bias | Client-heavy; efficient images; **minimal ethical telemetry**; user pays own bandwidth on bulk export |

## North star

Trustworthy fuel + maintenance history, **offline-safe logging**, full **data portability**, credible long-run economy and TCO — **without lock-in**.

## v1 scope (must ship)

- Multi-vehicle; sold/archive; VIN/tire/wheel fields (UX spec)
- Fill-ups: partial/full, missed-fill handling, consumption math + tests, hero economy + trends + price history
- Maintenance: recurring + one-off; archive on complete; estimates; dashboard vs simple list
- Photos: attach + queue; no OCR requirement
- Sync when online; staged hydration (logging never blocked on full download)
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

| Epic theme | Focus |
|------------|--------|
| Problem & users | ICP, v1 boundary |
| Core journeys | Fill-up, charts, maintenance, export, vehicles |
| Platform & compliance | Auth, sync, SI schema, media, export, GDPR/delete |
| Analytics & ops | Crash + reliability signals; operator cost — not monetization analytics |
| Launch | Privacy (export, sync, photos); donations = optional copy |

## Planning phases

| Phase | What | Status |
|-------|------|--------|
| **1 — Product brief** | This document | **Locked** |
| **2 — Solution + specs** | Stack spike → ADRs/architecture note → Git specs (consumption, sync, export, SI, images, telemetry allow-list) | Next |
| **3 — Delivery** | Linear breakdown, estimates, link `docs/specs/...` | After Phase 2 |

**Order:** Timeboxed **stack spike** → stack-dependent specs; **stack-agnostic** specs (e.g. consumption math) may run **in parallel** with the spike.

## Phase 2 checklist (engineering)

1. Spike: timebox + criteria (offline SQLite, camera, background sync, on-device export).
2. Specs in `docs/specs/`: consumption/fill-up; sync/conflict; export v1; SI + US gal; images; telemetry allow-list.
3. Legal / store: privacy, deletion, donation copy.
4. Linear: granular issues + spec links.

---

## Change log

| Date | Change |
|------|--------|
| 2026-04-06 | Baseline locked — initial brief from PM discovery. |
