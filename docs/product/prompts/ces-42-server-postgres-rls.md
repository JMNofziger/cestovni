# Cursor execution prompt — CES-42 Server Postgres + RLS migrations

> **Status: EXECUTED** (2026-10-20) — on `main` ([PR #33](https://github.com/JMNofziger/cestovni/pull/33)).
> Linear **[CES-42](https://linear.app/personal-interests-llc/issue/CES-42)** Done.
> Next in this chain was **[CES-43](https://linear.app/personal-interests-llc/issue/CES-43)**.
>
> Kept as an archive of the execution brief (do not re-run).

**Branch:** cut from **`main`**
**Spec (normative):** [`docs/specs/data-model.md`](../../specs/data-model.md) + [`docs/specs/adr/001-backend-api-boundary.md`](../../specs/adr/001-backend-api-boundary.md)
**Also read:** [`docs/specs/sync-protocol.md`](../../specs/sync-protocol.md) (server schema section) · [`docs/specs/adr/002-backup-sync-layer.md`](../../specs/adr/002-backup-sync-layer.md) · [`AGENTS.md`](../../../AGENTS.md)

---

## Handoff — where the repo is

| Item | State |
|------|-------|
| Last coding | **CES-49** settings CHECK (PR #30) + **CES-71** cadence rename (PR #29) on `main` |
| M0 | **Closed.** Client DB at schema v5 (5 migrations). |
| M1 | **Closed.** Offline logging end-to-end on Android. |
| M2 | **Closed.** Export + import on `main`. |
| M3 | **This ticket opens M3.** No server Postgres exists yet. |
| Dev sync stub | `server/dev-sync-stub/` — in-memory Node stub, fill_ups only, trivial bearer auth. NOT this ticket. Leave it untouched. |
| RLS CI | `.github/workflows/rls-regression.yml` — wired to Postgres 15 service container, but steps are TODO stubs. |
| RLS tests | `tests/rls/test_vehicles_rls.sql` — scaffold only; not runnable. |
| Contract tests | `tests/contract/README.md` — placeholder; no executable tests yet (that's CES-43). |

**Git start:** `git fetch origin && git checkout -b cursor/ces-42-<suffix> origin/main`

---

## Goal

Create the **server-side Postgres schema** for all v1 backed-up tables, with RLS policies, roles, and a runnable regression suite.

Concretely:

1. SQL migration files in `db/migrations/` numbered to match client Drift migrations
2. Postgres roles (`cestovni_app`, `cestovni_migrate`, `anon`)
3. `auth_user_id()` security-definer function
4. Shared sequence `cestovni_row_version_seq`
5. RLS policies per ADR 001 for every backed-up table
6. Runnable RLS regression tests in `tests/rls/`
7. CI workflow flipped from stubs to live

---

## Locked decisions (do not re-litigate)

### 1. Schema mirrors data-model.md exactly

The Postgres column names, types, and constraints must match `docs/specs/data-model.md`. Client uses SQLite (INT for booleans, TEXT for UUIDs); server uses native Postgres types:
- `id`, `user_id`, `mutation_id` → `UUID`
- `row_version` → `BIGINT` (from shared sequence)
- `updated_at` → `TIMESTAMPTZ DEFAULT now()`
- `deleted_at` → `TIMESTAMPTZ`
- Booleans → `BOOLEAN` (not INTEGER)
- `odometer_m`, `volume_uL`, `total_price_cents`, `cost_cents`, `tank_capacity_uL`, `cadence_m` → `BIGINT`

### 2. Migration numbering must align with client

Client migrations are 0001–0005. The **server** migrations carry the same numbers but may combine steps differently (e.g. the server doesn't need a "rename" migration since it never had the old column name — it can start with `cadence_m`). The server `0001_init.sql` creates all tables at their **current** shape (post-CES-71, post-CES-49), since there is no existing server data to migrate.

The required files:

```
db/migrations/
  0001_init.sql          -- roles, sequence, auth function, all 5 tables + RLS + indexes
```

A single init file is acceptable for v1 since there is no existing server database. Additional files can be added for future schema changes.

### 3. RLS policy shape — per data-model.md

```sql
-- Pattern for every backed-up table:
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
ALTER TABLE <table> FORCE ROW LEVEL SECURITY;  -- applies even to table owner

CREATE POLICY <table>_select_own ON <table> FOR SELECT
  USING (user_id = auth_user_id());
CREATE POLICY <table>_modify_own ON <table> FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());
```

Separate SELECT and ALL policies keep the grant model clean — `cestovni_app` gets `SELECT, INSERT, UPDATE` (no DELETE — soft-delete only in v1).

### 4. The `settings` table has `CHECK (user_id IS NULL OR id = user_id)`

Mirror the client constraint (CES-49). On the server `user_id` is never NULL (server-assigned from the token), so the effective behavior is `id = user_id`. But keep the same CHECK shape for parity.

### 5. No Docker Compose yet

The CI uses a GitHub Actions `services.db` Postgres 15 container. For local testing, the prompt runner should use `docker run` or a local Postgres. Do **not** add a full `docker-compose.yml` in this PR — that's infrastructure-as-code for the production stack (later).

A one-shot test script (`tests/rls/run.sh`) that applies migrations then runs RLS tests against a Postgres DSN is sufficient.

### 6. `auth_user_id()` is a stub for now

```sql
CREATE OR REPLACE FUNCTION auth_user_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::UUID;
$$;
```

This reads `user_id` from a session variable (`SET LOCAL app.user_id = '...'`). Real JWT integration (CES-43) will replace or wrap this. The RLS tests use `SET LOCAL` to simulate different users.

---

## Scope (in)

1. **`db/migrations/0001_init.sql`** — roles, sequence, `auth_user_id()`, all 5 backed-up tables (`vehicles`, `fill_ups`, `maintenance_rules`, `maintenance_events`, `settings`) with:
   - Full column set from `data-model.md` (current, post-CES-71/CES-49)
   - CHECK constraints matching client (fuel_type enum, currency_code GLOB equivalent, cadence at-least-one, settings id=user_id)
   - Foreign keys (`fill_ups.vehicle_id → vehicles.id`, `maintenance_events.vehicle_id → vehicles.id`, `maintenance_events.rule_id → maintenance_rules.id`)
   - Indexes per `data-model.md` § Indexes
   - RLS policies per locked decision 3
   - `GRANT` statements for `cestovni_app` role (SELECT, INSERT, UPDATE on all backed-up tables; USAGE on sequence)
2. **`tests/rls/`** — one test file per table (`test_vehicles_rls.sql`, `test_fill_ups_rls.sql`, `test_maintenance_rules_rls.sql`, `test_maintenance_events_rls.sql`, `test_settings_rls.sql`) covering every row in the test matrix from `tests/rls/README.md`.
3. **`tests/rls/run.sh`** — shell script: takes `$DATABASE_URL`, applies `db/migrations/0001_init.sql`, creates test users, runs each `test_*.sql` via `psql`, reports PASS/FAIL.
4. **`.github/workflows/rls-regression.yml`** — flip from TODO stubs to running `tests/rls/run.sh` against the `services.db` Postgres 15 container.
5. **`db/README.md`** — brief: what's here, how to run migrations locally, how to run RLS tests.
6. **`docs/specs/data-model.md`** — update the "Current client layout" paragraph to note the server migration now exists.

## Scope (out)

- **API server code** (CES-43)
- **Contract tests** (CES-43)
- **Client changes** (none needed)
- **Docker Compose** or production deployment
- **Real JWT / OIDC** (CES-43 wires this)
- **Dev sync stub changes** (leave `server/dev-sync-stub/` untouched)

## Constraints

- Postgres 15+ (matches CI service image).
- `psql` is the only required tool for migrations and tests (no ORM, no Prisma, no Knex).
- RLS tests must use two distinct simulated users with `SET LOCAL app.user_id`.
- `python3 ci/telemetry-gate.py` must still pass (no client changes).
- The existing `verify-fast.yml` and `verify-full.yml` pipelines must remain green.

## Acceptance

- [x] `db/migrations/0001_init.sql` creates all 5 tables with correct columns, types, constraints, indexes, RLS policies, roles, sequence, and `auth_user_id()`.
- [x] Each backed-up table has tests for: own read ✓, cross-user read ✗, own update ✓, cross-user update ✗, cross-user delete ✗, valid-ownership insert ✓, invalid-ownership insert ✗.
- [x] `tests/rls/run.sh` runs against a fresh Postgres and exits 0 on success.
- [x] `ci/rls-regression.yml` no longer has TODO stubs; CI runs the actual tests.
- [x] `settings` table has `CHECK (user_id IS NULL OR id = user_id)` parity with client.
- [x] `cadence_m` (not `cadence_km`) on `maintenance_rules`.
- [x] `db/README.md` documents the migration approach.
- [x] `delivery-plan-v1.md` M3 rollup / CES-42 row → 🟩.
- [x] Linear CES-42 Done + closeout comment.

## Status report (required)

1. Migration file structure and key design choices
2. How `auth_user_id()` is implemented for the test harness
3. RLS test coverage summary (tables × cases)
4. CI workflow changes
5. Known limits (e.g. no real JWT yet — that's CES-43)
6. PR URL + Linear CES-42 state

Tag: `CES-42 — Server Postgres + RLS`.
