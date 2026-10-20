# `db/` — server Postgres

Server schema for the five v1 backed-up tables (`vehicles`, `fill_ups`,
`maintenance_rules`, `maintenance_events`, `settings`). Normative shape:
[`docs/specs/data-model.md`](../docs/specs/data-model.md). RLS and roles:
[ADR 001](../docs/specs/adr/001-backend-api-boundary.md).

## What `0001_init.sql` does

One migration, not a replay of client steps 0002–0005. There is no existing
server data. The file creates the schema at the **current** client shape
(schema v5 backed-up columns): `cadence_m`, settings `CHECK (user_id IS NULL OR id = user_id)`,
native Postgres types. Client schema v6 (CES-45) adds local-only `sync_cursors`
and `backup_marks`. Those tables are not on the server.

| Object | Purpose |
| --- | --- |
| `cestovni_migrate` | Owns tables, sequence, and functions. DDL only. `NOLOGIN`. |
| `cestovni_app` | Runtime. `SELECT`, `INSERT`, `UPDATE`. No `DELETE` (soft-delete is an `UPDATE` of `deleted_at`). No `BYPASSRLS`. |
| `anon` | No table privileges. |
| `cestovni_row_version_seq` | Shared `BIGINT` sequence. `cestovni_touch_row()` assigns `row_version` and `updated_at` on insert and update. |
| `auth_user_id()` | Stub. Reads `current_setting('app.user_id', true)`. CES-43 replaces the token source; callers still `SET LOCAL app.user_id`. |

RLS is enabled and **forced** on every backed-up table:

- `<table>_select_own` — `FOR SELECT USING (user_id = auth_user_id())`
- `<table>_modify_own` — `FOR ALL` with the same predicate in `USING` and `WITH CHECK`

`volume_uL` and `tank_capacity_uL` are quoted identifiers so the mixed case
from the data model survives Postgres folding.

Apply as a superuser on an **empty** database. Tables and policies are not
idempotent (a second apply into the same database fails). Roles are
cluster-wide and are created only when missing, so a new database on a
cluster that already has the roles still applies.

```bash
createdb cestovni
psql "postgresql:///cestovni" -v ON_ERROR_STOP=1 -f db/migrations/0001_init.sql
```

There is no `docker-compose.yml` in this change. CI uses the Postgres 15
service container in [`.github/workflows/rls-regression.yml`](../.github/workflows/rls-regression.yml).
Locally, any Postgres 15+ instance is enough (`docker run postgres:15` or a
package install).

## RLS tests

```bash
createdb cestovni_rls
DATABASE_URL=postgresql:///cestovni_rls ./tests/rls/run.sh
```

`run.sh` applies the migration, checks `auth_user_id()` against two simulated
users, then runs `tests/rls/test_*_rls.sql`. The connection must be a
superuser so the script can `SET ROLE`. Tests set `app.user_id` themselves;
they do not use per-user database roles.

| Simulated user | `app.user_id` |
| --- | --- |
| A | `11111111-1111-4111-8111-111111111111` |
| B | `22222222-2222-4222-8222-222222222222` |

Drop `cestovni_rls` before running the script again.

## Index notes (ADR 001 guardrail)

Policies and the catch-up query both filter on columns that have an index:

- Ownership / live rows: `vehicles_user_id_idx`, `vehicles_user_live_idx`, and the partial `(user_id, …) WHERE deleted_at IS NULL` indexes on `fill_ups`, `maintenance_rules`, and `maintenance_events`.
- `GET /changes` (`row_version > :since ORDER BY row_version`): `*_row_version_idx` on each table, plus the composite `(user_id, row_version)` indexes where the spec defines them.
- Settings lookup by owner: unique `settings_user_id_uidx`.

`cestovni_app` has no `DELETE`, so a cross-user `DELETE` is `insufficient_privilege` rather than a silent zero-row update. That is deliberate for v1.
