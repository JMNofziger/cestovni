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
| `cestovni_app` | Runtime. `SELECT`, `INSERT`, `UPDATE` on product tables. No `DELETE` (soft-delete is an `UPDATE` of `deleted_at`). No `BYPASSRLS`. No identity-table grants. |
| `cestovni_auth` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` on the five identity tables. `NOLOGIN`. No product-table grants. |
| `cestovni_purge` | `SELECT` and `DELETE` on the five product tables through existing RLS. `NOLOGIN`. No `INSERT`, `UPDATE`, or `TRUNCATE`. |
| `anon` | No table privileges. |
| `cestovni_row_version_seq` | Shared `BIGINT` sequence. `cestovni_touch_row()` assigns `row_version` and `updated_at` on insert and update. |
| `auth_user_id()` | Stub. Reads `current_setting('app.user_id', true)`. CES-43 replaces the token source; callers still `SET LOCAL app.user_id`. |
| `users` | API UUID `id`, unique `google_sub`, nullable `email`. No RLS. |
| `auth_sessions` | Session row. `user_id` references `users` on delete cascade. |
| `auth_refresh_tokens` | 32-byte `token_hash`, unique. Cascades from the session. |
| `auth_oauth_states` | Hashed OAuth state, PKCE verifier, `client`, `nonce`. |
| `auth_login_transactions` | Hashed login code, `google_sub`, nullable `email`. No `user_id` and no foreign key. |

RLS is enabled and **forced** on every backed-up table:

- `<table>_select_own` — `FOR SELECT USING (user_id = auth_user_id())`
- `<table>_modify_own` — `FOR ALL` with the same predicate in `USING` and `WITH CHECK`

`volume_uL` and `tank_capacity_uL` are quoted identifiers so the mixed case
from the data model survives Postgres folding.

`0002_identity.sql` adds `cestovni_auth`, `cestovni_purge`, and the five
identity tables. Those tables have no RLS. Product tables gain no foreign
key to `users`.

Apply with the migration runner as a superuser (or equivalent). It applies
`0001_init.sql` then `0002_identity.sql` and records them. A second run
changes nothing. Roles are cluster-wide and are created only when missing.

`node-pg` does not accept a `psql`-style DSN with no host (`postgresql:///db`).
Use a TCP URL, or `?host=/var/run/postgresql` for the local socket.

```bash
createdb cestovni
cd server/api && npm ci
DATABASE_URL='postgresql:///cestovni?host=/var/run/postgresql' npm run migrate
```

There is no `docker-compose.yml` in this change. CI uses the Postgres 15
service container in [`.github/workflows/rls-regression.yml`](../.github/workflows/rls-regression.yml).
Locally, any Postgres 15+ instance is enough (`docker run postgres:15` or a
package install).

## RLS tests

```bash
createdb cestovni_rls
(cd server/api && npm ci)
DATABASE_URL='postgresql:///cestovni_rls?host=/var/run/postgresql' ./tests/rls/run.sh
```

`run.sh` applies migrations through `server/api/scripts/migrate.js`, checks
`auth_user_id()` against two simulated users, then runs
`tests/rls/test_*_rls.sql`. The connection must be a superuser so the script
can `SET ROLE`. The same `DATABASE_URL` has to work for Node, so it needs a
host (see above). Tests set `app.user_id` themselves; they do not use
per-user database roles. The migration step is re-runnable.

| Simulated user | `app.user_id` |
| --- | --- |
| A | `11111111-1111-4111-8111-111111111111` |
| B | `22222222-2222-4222-8222-222222222222` |

## Index notes (ADR 001 guardrail)

Policies and the catch-up query both filter on columns that have an index:

- Ownership / live rows: `vehicles_user_id_idx`, `vehicles_user_live_idx`, and the partial `(user_id, …) WHERE deleted_at IS NULL` indexes on `fill_ups`, `maintenance_rules`, and `maintenance_events`.
- `GET /changes` (`row_version > :since ORDER BY row_version`): `*_row_version_idx` on each table, plus the composite `(user_id, row_version)` indexes where the spec defines them.
- Settings lookup by owner: unique `settings_user_id_uidx`.

`cestovni_app` has no `DELETE`, so a cross-user `DELETE` is `insufficient_privilege` rather than a silent zero-row update. That is deliberate for v1.
