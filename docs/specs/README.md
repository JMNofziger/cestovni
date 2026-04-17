# Specs

**Browse on GitHub:** [github.com/JMNofziger/cestovni — `docs/specs/`](https://github.com/JMNofziger/cestovni/tree/main/docs/specs) · Repo root [README.md](../../README.md).

Put feature and technical specs here as Markdown (e.g. `CES-123-short-name.md`).

Each Linear issue should include a **`Spec:`** line pointing to the relevant file in this folder (or `TBD` for spikes / early discovery).

**Process:** Follow stage gates in [`../product/PRODUCT_DEV_WORKFLOW.md`](../product/PRODUCT_DEV_WORKFLOW.md) — architecture ADRs before finalizing stack-bound specs; optional timeboxed client POC only when needed.

## Index (Phase 2)

| Doc                                                  | Purpose                                    | Linear         | Status                                 |
| ---------------------------------------------------- | ------------------------------------------ | -------------- | -------------------------------------- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md)                 | System overview + links                    | CES-25         | Agreed for v1 kickoff                  |
| [`adr/README.md`](adr/README.md)                     | ADR index                                  | CES-23, CES-24 | Both Accepted                          |
| [`consumption-math.md`](consumption-math.md)         | Math, segments, fill-up flags              | CES-26         | Complete (v1)                          |
| [`si-units.md`](si-units.md)                         | Canonical INT storage + conversions        | CES-27         | Complete (v1)                          |
| [`export-v1.md`](export-v1.md)                       | ZIP / CSV export contract                  | CES-28         | Complete (v1)                          |
| [`telemetry-allowlist.md`](telemetry-allowlist.md)   | Crash + product event allow-list           | CES-29         | Complete (v1)                          |
| [`telemetry-events.v1.yaml`](telemetry-events.v1.yaml) | Machine-readable event catalogue         | CES-29         | Complete (v1)                          |
| [`photo-pipeline.md`](photo-pipeline.md)             | Ephemeral photos / deferred entry          | CES-30         | Complete (v1)                          |
| [`sync-protocol.md`](sync-protocol.md)               | Backup protocol + v1.x roadmap             | CES-31         | Complete for v1; v1.x roadmap deferred |
| [`data-model.md`](data-model.md)                     | Client SQLite + server Postgres schemas    | CES-32         | Complete (v1)                          |
| [`self-host-runbook.md`](self-host-runbook.md)       | Backend-only continuity bootstrap          | CES-33         | Draft (executable minimum)             |
| [`platform-compliance-v1.md`](platform-compliance-v1.md) | Privacy / deletion / store posture | CES-8 (Stage 4)| Complete (v1)                          |
| [`TBD-launch.md`](TBD-launch.md)                     | Launch criteria & rollback                 | Stage 6        | Stub                                   |
