# Cestovni

Cross-platform **fuel and maintenance** log: offline-first, structured **backup/restore**, full **ZIP/CSV export**, and **continuity-first** architecture (managed service with a **backend-only self-host** path for technical users).

**Repository:** [github.com/JMNofziger/cestovni](https://github.com/JMNofziger/cestovni) · default branch **`main`**

## Product and process

| Document | Description |
| -------- | ----------- |
| [Product brief](https://github.com/JMNofziger/cestovni/blob/main/docs/product/PRODUCT_BRIEF.md) | Locked baseline: principles, v1 scope, monetization, change log |
| [Development workflow](https://github.com/JMNofziger/cestovni/blob/main/docs/product/PRODUCT_DEV_WORKFLOW.md) | Stage gates (specs, compliance, delivery, launch) |
| [Product folder README](https://github.com/JMNofziger/cestovni/blob/main/docs/product/README.md) | Pointers into product docs + Linear |

## Technical specs and ADRs

| Resource | Description |
| -------- | ----------- |
| [Specs index](https://github.com/JMNofziger/cestovni/blob/main/docs/specs/README.md) | All Markdown specs, status, and Linear issue mapping |
| [Architecture overview](https://github.com/JMNofziger/cestovni/blob/main/docs/specs/ARCHITECTURE.md) | System shape and links to ADRs |
| [ADR index](https://github.com/JMNofziger/cestovni/blob/main/docs/specs/adr/README.md) | Backend boundary (001), backup/sync (002) |

**Compliance and store (v1):** [platform-compliance-v1.md](https://github.com/JMNofziger/cestovni/blob/main/docs/specs/platform-compliance-v1.md) · **Launch copy skeletons:** [launch-copy-v1.md](https://github.com/JMNofziger/cestovni/blob/main/docs/product/launch-copy-v1.md)

## Mobile client (Stage 5 / M0)

- **Source:** [`client/`](https://github.com/JMNofziger/cestovni/tree/main/client) — Flutter + Drift; runbook in [`client/README.md`](https://github.com/JMNofziger/cestovni/blob/main/client/README.md)
- **CI (GitHub Actions–shaped):** [`ci/client-build.yml`](https://github.com/JMNofziger/cestovni/blob/main/ci/client-build.yml) — analyze, test, Android debug APK, iOS debug (no codesign)
- **DB fixtures (human-readable):** [`tests/client-db/`](https://github.com/JMNofziger/cestovni/tree/main/tests/client-db)

## Engineering scaffolding

- [RLS regression CI](https://github.com/JMNofziger/cestovni/blob/main/ci/rls-regression.yml) · [Promotion gates](https://github.com/JMNofziger/cestovni/blob/main/ci/promotion-gates.yml) · [Telemetry gate](https://github.com/JMNofziger/cestovni/blob/main/ci/telemetry-gate.yml) · [Client build](https://github.com/JMNofziger/cestovni/blob/main/ci/client-build.yml)
- Tests under [`tests/`](https://github.com/JMNofziger/cestovni/tree/main/tests) and [`client/test/`](https://github.com/JMNofziger/cestovni/tree/main/client/test)

## Linear

**Project:** [Cestovni on Linear](https://linear.app/personal-interests-llc/project/cestovni-e4d462505e62) — team **Cestovni**. Issues use a **`Spec:`** line with a path under this repo (see [issue templates](https://github.com/JMNofziger/cestovni/blob/main/docs/linear/issue-templates.md)).

**Baseline pointer:** [CES-20](https://linear.app/personal-interests-llc/issue/CES-20/meta-product-brief-baseline-locked-see-git)

## Local clone

```bash
git clone https://github.com/JMNofziger/cestovni.git
cd cestovni
```

Linear API scripts (optional): see [docs/linear/saved-views.md](https://github.com/JMNofziger/cestovni/blob/main/docs/linear/saved-views.md).
