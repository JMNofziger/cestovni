# ci/ — continuous integration scaffolding

Stubs and working gates for Cestovni. All `.yml` files are shaped for GitHub Actions; adapt at the point the chosen CI platform is wired up.

| File | Purpose | State | Spec / ADR |
|------|---------|-------|------------|
| [`rls-regression.yml`](rls-regression.yml) | RLS / authorization regression tests against a temporary Postgres | Stub (lands real in M3) | [ADR 001](../docs/specs/adr/001-backend-api-boundary.md), `tests/rls/` |
| [`promotion-gates.yml`](promotion-gates.yml) | Migration dry-run + RLS + contract + restore smoke on release | Stub (lands real in M3) | [ADR 001](../docs/specs/adr/001-backend-api-boundary.md) |
| [`telemetry-gate.yml`](telemetry-gate.yml) | Enforces the telemetry allow-list YAML + client-source scan when client exists | **Live** — validates YAML + client today | [`telemetry-allowlist.md`](../docs/specs/telemetry-allowlist.md) §"CI gate" |
| [`telemetry-gate.py`](telemetry-gate.py) | Validator script invoked by the telemetry-gate workflow | **Live** (client scanner active as of CES-36 / M0-01) | same |
| [`telemetry-schema.json`](telemetry-schema.json) | JSON Schema for `telemetry-events.v1.yaml`; bans `identifier` / `freetext` | **Live** | same |
| [`client-build.yml`](client-build.yml) | Flutter test + Android/iOS debug build lanes | **Live** (M0-01) | [ADR 003](../docs/specs/adr/003-mobile-stack.md) |

## Running the telemetry gate locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml jsonschema
python ci/telemetry-gate.py
```

Expected output on a clean repo:

```
telemetry-gate: starting
[1/4] YAML parsed: N events.
[3/4] JSON Schema validation passed (identifier/freetext classes banned at schema level).
[2/4] client scan passed: M Dart file(s), K literal emit call(s), 0 unknown.
[4/4] SKIP — Apple PrivacyInfo.xcprivacy not present yet; will compare category totals when the mobile client ships.
telemetry-gate: PASS
```

Exit code 0 pass, 1 fail.

## Check status

- **Check 2 (client-source scan):** **Live as of CES-36 / M0-01**. The
  scanner walks `client/lib/**/*.dart`, matches
  `Telemetry.emit('name', …)` with a literal string argument, and hard-
  fails on unknown names or on non-literal (dynamic) arguments — the
  only way CI can reason about the call statically.
- **Check 4 (Apple PrivacyInfo drift):** auto-activates once
  `apple/PrivacyInfo.xcprivacy` or `ios/Runner/PrivacyInfo.xcprivacy` is
  authored (Stage 6 / store submission). The current implementation
  prints categories but does not yet parse
  `NSPrivacyCollectedDataTypes`; extend before store submission.

## Related

- [`../docs/specs/telemetry-allowlist.md`](../docs/specs/telemetry-allowlist.md) — principles, allow-list, CI gate contract.
- [`../docs/specs/telemetry-events.v1.yaml`](../docs/specs/telemetry-events.v1.yaml) — authoritative event catalogue.
- [`../docs/specs/platform-compliance-v1.md`](../docs/specs/platform-compliance-v1.md) §5.3, §8 — pepper lifecycle + Apple / Play mapping.
- [`../docs/product/delivery-plan-v1.md`](../docs/product/delivery-plan-v1.md) — Milestone 4 wires the client-side emit function against this gate.
