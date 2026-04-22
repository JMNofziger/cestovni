# Spec: Data model (client SQLite + server Postgres)

**Status:** Complete (v1)
**Linear:** CES-32
**Depends on:** [ADR 001](adr/001-backend-api-boundary.md), [ADR 002](adr/002-backup-sync-layer.md), [`si-units.md`](si-units.md), [`consumption-math.md`](consumption-math.md), [`photo-pipeline.md`](photo-pipeline.md), [`sync-protocol.md`](sync-protocol.md)

## Purpose

Concrete table list, column types, constraints, indexing, RLS shape, and migration alignment rules for v1. Every backed-up row obeys the ADR 002 protocol columns. Client SQLite (Drift) and server Postgres mirror the same logical schema, with Postgres authoritative.

## Conventions

- **Canonical SI integers** per [`si-units.md`](si-units.md): volume in µL, distance in m, money in cents (+ currency code).
- **Timestamps:** `TIMESTAMPTZ` (Postgres) / `TEXT ISO-8601 UTC` (SQLite).
- **UUIDs:** v4, client-generated, stable across devices.
- **NOT NULL by default**; columns noted as nullable have explicit domain reasons.
- **CHECK constraints** enforce non-negative canonical physical columns at the DB layer.

## Protocol columns (every backed-up table)

From [ADR 002](adr/002-backup-sync-layer.md#protocol-primitives-v1). Every table in the "backed-up" section below carries these columns verbatim:

| Column        | Postgres type    | SQLite type     | Notes                                                                         |
| ------------- | ---------------- | --------------- | ----------------------------------------------------------------------------- |
| `id`          | `UUID`           | `TEXT`          | Client-generated at creation; primary key.                                    |
| `user_id`     | `UUID`           | `TEXT`          | Server-assigned from auth token on first write; NEVER sent by the client.     |
| `row_version` | `BIGINT`         | `INTEGER`       | Server-assigned from `cestovni_row_version_seq`; not written by the client.   |
| `updated_at`  | `TIMESTAMPTZ`    | `TEXT`          | `DEFAULT now()`; human readability only.                                      |
| `deleted_at`  | `TIMESTAMPTZ NULL` | `TEXT NULL`   | Soft-delete marker; NULL when live.                                           |
| `mutation_id` | `UUID`           | `TEXT`          | Last idempotency key that touched the row; server dedupes retries.            |

On the **client**, `row_version`, `user_id`, and `updated_at` are hydrated from the server response after each successful `POST /mutations` (see [`sync-protocol.md`](sync-protocol.md)).

## Backed-up tables (server authoritative)

### `vehicles`

| Column            | Type              | Constraints                                                   | Notes                                              |
| ----------------- | ----------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| *(protocol cols)* | *(see above)*     |                                                               |                                                    |
| `name`            | `TEXT`            | NOT NULL, `length(name) BETWEEN 1 AND 80`                     | User-facing display name.                          |
| `make`            | `TEXT NULL`       | `length <= 80`                                                | Free-text; no make/model catalog in v1.            |
| `model`           | `TEXT NULL`       | `length <= 80`                                                |                                                    |
| `year`            | `SMALLINT NULL`   | `CHECK (year IS NULL OR year BETWEEN 1900 AND 2100)`          |                                                    |
| `vin`             | `TEXT NULL`       | `length <= 32`                                                | No uniqueness constraint; user may type it wrong.  |
| `fuel_type`       | `TEXT`            | `CHECK (fuel_type IN ('gasoline','diesel','lpg','cng','ev_kwh','other'))` | See enum discussion below.              |
| `tank_capacity_uL`| `BIGINT NULL`     | `CHECK (tank_capacity_uL IS NULL OR tank_capacity_uL >= 0)`   | Optional; informational only.                      |
| `archived_at`     | `TIMESTAMPTZ NULL`|                                                               | Archived vehicles keep history; excluded from defaults. |

**Indexes:**

```sql
CREATE INDEX vehicles_user_id_idx        ON vehicles (user_id);
CREATE INDEX vehicles_user_live_idx      ON vehicles (user_id) WHERE deleted_at IS NULL;
CREATE INDEX vehicles_row_version_idx    ON vehicles (row_version);
```

### `fill_ups`

| Column              | Type              | Constraints                                                       | Notes                                                |
| ------------------- | ----------------- | ----------------------------------------------------------------- | ---------------------------------------------------- |
| *(protocol cols)*   | *(see above)*     |                                                                   |                                                      |
| `vehicle_id`        | `UUID`            | NOT NULL, FK → `vehicles.id` (no `ON DELETE CASCADE`)             | Soft-delete the vehicle; history remains.            |
| `filled_at`         | `TIMESTAMPTZ`     | NOT NULL                                                           | User-provided UTC timestamp.                         |
| `odometer_m`        | `BIGINT`          | NOT NULL, `CHECK (odometer_m >= 0)`                               | Canonical meters.                                    |
| `volume_uL`         | `BIGINT`          | NOT NULL, `CHECK (volume_uL >= 0)`                                | Canonical µL.                                        |
| `total_price_cents` | `BIGINT`          | NOT NULL, `CHECK (total_price_cents >= 0)`                        | Canonical cents.                                     |
| `currency_code`     | `CHAR(3)`         | NOT NULL, `CHECK (currency_code ~ '^[A-Z]{3}$')`                  | ISO 4217.                                            |
| `is_full`           | `BOOLEAN`         | NOT NULL                                                           | See [`consumption-math.md`](consumption-math.md).    |
| `missed_before`     | `BOOLEAN`         | NOT NULL DEFAULT `false`                                           |                                                      |
| `odometer_reset`    | `BOOLEAN`         | NOT NULL DEFAULT `false`                                           | Gates the regression rule.                           |
| `notes`             | `TEXT NULL`       | `length <= 500`                                                   |                                                      |

**Indexes:**

```sql
CREATE INDEX fill_ups_user_vehicle_time_idx
  ON fill_ups (user_id, vehicle_id, filled_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX fill_ups_user_row_version_idx ON fill_ups (user_id, row_version);
CREATE INDEX fill_ups_vehicle_id_idx       ON fill_ups (vehicle_id);
```

### `maintenance_rules`

| Column            | Type              | Constraints                                                     | Notes                               |
| ----------------- | ----------------- | --------------------------------------------------------------- | ----------------------------------- |
| *(protocol cols)* | *(see above)*     |                                                                 |                                     |
| `vehicle_id`      | `UUID`            | NOT NULL, FK → `vehicles.id`                                    |                                     |
| `name`            | `TEXT`            | NOT NULL, `length BETWEEN 1 AND 80`                             | e.g. "Oil change".                  |
| `cadence_km`      | `BIGINT NULL`     | `CHECK (cadence_km IS NULL OR cadence_km > 0)`                  | Canonical meters.                   |
| `cadence_days`    | `INTEGER NULL`    | `CHECK (cadence_days IS NULL OR cadence_days > 0)`              |                                     |
| `enabled`         | `BOOLEAN`         | NOT NULL DEFAULT `true`                                          |                                     |
| `notes`           | `TEXT NULL`       | `length <= 500`                                                 |                                     |

Rule: `cadence_km` OR `cadence_days` (or both) must be non-null; enforced by table-level `CHECK (cadence_km IS NOT NULL OR cadence_days IS NOT NULL)`.

**Indexes:**

```sql
CREATE INDEX maintenance_rules_user_vehicle_idx
  ON maintenance_rules (user_id, vehicle_id)
  WHERE deleted_at IS NULL;
CREATE INDEX maintenance_rules_user_row_version_idx ON maintenance_rules (user_id, row_version);
```

### `maintenance_events`

| Column            | Type              | Constraints                                                                                                          | Notes                                                                                 |
| ----------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| *(protocol cols)* | *(see above)*     |                                                                                                                      |                                                                                       |
| `vehicle_id`      | `UUID`            | NOT NULL, FK → `vehicles.id`                                                                                         |                                                                                       |
| `rule_id`         | `UUID NULL`       | FK → `maintenance_rules.id` (nullable — one-off events allowed)                                                      |                                                                                       |
| `performed_at`    | `TIMESTAMPTZ`     | NOT NULL                                                                                                             |                                                                                       |
| `odometer_m`      | `BIGINT NULL`     | `CHECK (odometer_m IS NULL OR odometer_m >= 0)`                                                                      | Optional — form allows leaving blank ([CES-53](https://linear.app/personal-interests-llc/issue/CES-53)). |
| `cost_cents`      | `BIGINT`          | NOT NULL, `CHECK (cost_cents >= 0)` DEFAULT 0                                                                        | Form writes `0` when user leaves the field blank.                                     |
| `currency_code`   | `CHAR(3)`         | NOT NULL, same check as `fill_ups.currency_code`                                                                     | Defaults to `settings.currency_code` when the form doesn't prompt.                    |
| `category`        | `TEXT`            | NOT NULL DEFAULT `'other'`, `CHECK (category IN ('oil','tires','brakes','inspection','battery','fluid','other'))`   | Required in the UX form; closed enum so metrics can bucket on it.                      |
| `shop`            | `TEXT NULL`       | `CHECK (shop IS NULL OR length(shop) BETWEEN 1 AND 120)`                                                             | Optional vendor/shop name.                                                            |
| `notes`           | `TEXT NULL`       | `length <= 500`                                                                                                      |                                                                                       |

**Indexes:**

```sql
CREATE INDEX maintenance_events_user_vehicle_time_idx
  ON maintenance_events (user_id, vehicle_id, performed_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX maintenance_events_user_row_version_idx ON maintenance_events (user_id, row_version);
```

### `settings`

Exactly one row per user. The `id` column equals the `user_id` for simplicity; this is legal because `user_id` is already a UUID.

| Column                   | Type           | Constraints                                                              | Notes                                     |
| ------------------------ | -------------- | ------------------------------------------------------------------------ | ----------------------------------------- |
| *(protocol cols)*        | *(see above)*  | `id = user_id` enforced by trigger (or app-level invariant).              |                                           |
| `preferred_distance_unit`| `TEXT`         | NOT NULL, `CHECK (preferred_distance_unit IN ('km','mi'))`               |                                           |
| `preferred_volume_unit`  | `TEXT`         | NOT NULL, `CHECK (preferred_volume_unit IN ('L','gal'))`                 |                                           |
| `currency_code`          | `CHAR(3)`      | NOT NULL, same check as above                                             | Default currency for new fill-ups/events. |
| `timezone`               | `TEXT`         | NOT NULL, `length BETWEEN 1 AND 64`                                       | IANA name (e.g. `Europe/Prague`).         |

**Indexes:**

```sql
CREATE UNIQUE INDEX settings_user_id_uidx ON settings (user_id);
CREATE INDEX settings_row_version_idx    ON settings (row_version);
```

## Enum discussion

We chose a **TEXT + CHECK constraint** instead of Postgres `ENUM` types for two reasons:

1. **Migration cost.** Postgres enum modifications are historically painful in migrations; adding a new fuel type (e.g. `hydrogen`) is a one-line change to the CHECK list.
2. **Client parity.** SQLite has no native enum. Mirroring a CHECK constraint is trivial on both engines.

If a future vertical (fleet B2B) justifies reference tables instead, it becomes a schema-migration concern, not a protocol concern.

## Client-only tables (never backed up)

These live **only** in the client SQLite database. They carry **no** protocol columns and never appear in outbox mutations or `/changes` responses.

### `outbox`

Schema already defined in [`sync-protocol.md` — Client outbox](sync-protocol.md#client-outbox-local-only). This spec adds only one cross-reference note: `outbox.row_id` → points to a row in one of the backed-up tables above; `outbox.table` MUST be one of `vehicles | fill_ups | maintenance_rules | maintenance_events | settings`.

### `drafts`

In-progress fill-ups not yet promoted to `fill_ups`. Never outboxed; never exported (see [`export-v1.md`](export-v1.md)).

| Column            | Type             | Notes                                                              |
| ----------------- | ---------------- | ------------------------------------------------------------------ |
| `id`              | `TEXT` (UUID)    | PK. When promoted, becomes `fill_ups.id`.                          |
| `vehicle_id`      | `TEXT NULL`      | May be unset if the user hasn't picked a vehicle yet.              |
| `created_at`      | `TEXT`           | UTC ISO-8601.                                                      |
| `filled_at`       | `TEXT NULL`      |                                                                    |
| `odometer_m`      | `INTEGER NULL`   |                                                                    |
| `volume_uL`       | `INTEGER NULL`   |                                                                    |
| `total_price_cents`| `INTEGER NULL`  |                                                                    |
| `currency_code`   | `TEXT NULL`      |                                                                    |
| `is_full`         | `INTEGER NULL`   |                                                                    |
| `missed_before`   | `INTEGER NULL`   |                                                                    |
| `odometer_reset`  | `INTEGER NULL`   |                                                                    |
| `notes`           | `TEXT NULL`      |                                                                    |
| `completed_at`    | `TEXT NULL`      | Set when promoted; drives photo 7-day post-completion TTL.         |

### `photo_refs`

Schema defined in [`photo-pipeline.md` — `photo_refs` table](photo-pipeline.md#photo_refs-table-client-only-never-outboxed). Client-only; referenced here so there is one place that lists every client-side table.

## RLS (Postgres)

Every backed-up table is `ENABLE ROW LEVEL SECURITY`. Policies are identical across tables except for table name; managed by a shared SQL macro in `db/migrations/`. The policy shape:

```sql
-- Example for fill_ups; repeated for every backed-up table.
ALTER TABLE fill_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE fill_ups FORCE ROW LEVEL SECURITY;

CREATE POLICY fill_ups_select_own
  ON fill_ups FOR SELECT
  USING (user_id = auth_user_id());

CREATE POLICY fill_ups_modify_own
  ON fill_ups FOR UPDATE
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

CREATE POLICY fill_ups_insert_own
  ON fill_ups FOR INSERT
  WITH CHECK (user_id = auth_user_id());

CREATE POLICY fill_ups_delete_own
  ON fill_ups FOR DELETE
  USING (user_id = auth_user_id());
```

- `auth_user_id()` is a SECURITY-DEFINER function that reads the verified JWT claim, defined once in migrations. Self-host operators install the same function; the token source differs but the claim shape does not (see [ADR 001 identity model](adr/001-backend-api-boundary.md#security-model)).
- The runtime role `cestovni_app` has only `SELECT, INSERT, UPDATE` on backed-up tables and **no BYPASSRLS**, per [ADR 001 role model](adr/001-backend-api-boundary.md#role-model).
- The RLS regression suite in `tests/rls/` covers allow/deny for each table and cross-user checks (ADR 001 gate).

## Migration alignment (client ↔ server)

### Layout

```
db/
  migrations/
    0001_init.sql
    0002_add_maintenance_events_category_shop.sql
    ...
client/
  drift/
    migrations/
      0001_init.dart
      0002_add_maintenance_events_category_shop.dart
      ...
```

Numbers are aligned: every server migration `NNNN_*.sql` has a matching client Drift migration `NNNN_*.dart` (or equivalent in whichever client stack ships).

**Current client layout (M0, Flutter + Drift):** schema and steps live under [`client/lib/db/`](../../client/lib/db/) (`schema_steps.dart` + `migration_runner.dart`; `0001_init` = v0→v1). The illustrative `client/drift/migrations/` tree above is conceptual — keep **numeric alignment** with `db/migrations/` when the server lands.

### Rules

1. **Add column**: ship server migration first in release N; client migration in the **same** release N. Ordering within the release: server deployed before the client version hits the store; the client tolerates servers that already have the column (extra field on read is ignored if unknown; SDK defaults to current schema).
2. **Remove column**: ship a **deprecation release** (N) where the client stops writing the column; ship the server migration that drops it in release N+1 after all active clients are at ≥N.
3. **Rename column**: do not rename. Add new + backfill + deprecate old, per above.
4. **Breaking type change**: forbidden without a `schema_version` bump in `manifest.json` (export) and a coordinated release; treat as a multi-step migration.
5. **Every migration PR**: ships with updated RLS tests (ADR 001), updated protocol tests (ADR 002), and an `EXPLAIN` note for any new indexed predicate ([ADR 001 index guardrails](adr/001-backend-api-boundary.md#index-and-performance-guardrails)).

### Client schema migration rollback (footnote)

Client-side rollback (if a release corrupts the local DB) is handled by:

- Drift's automatic migration execution (forward only);
- a **hard reset + restore** fallback path — the user signs in again and the app rebuilds local SQLite from `GET /changes` (see [`sync-protocol.md`](sync-protocol.md)). Tooling to trigger this manually from Settings is **Stage 5** work.

## Constraints summary (one place)

| Constraint kind        | Example                                                    | Enforced where                        |
| ---------------------- | ---------------------------------------------------------- | ------------------------------------- |
| Non-negative integer   | `volume_uL >= 0`                                           | DB CHECK + client validation          |
| Enum membership        | `fuel_type IN (...)`                                       | DB CHECK + TS/Dart enum type          |
| ISO 4217 format        | `currency_code ~ '^[A-Z]{3}$'`                             | DB CHECK + client validator           |
| Odometer regression    | `odometer_m >= prev.odometer_m` unless `odometer_reset`    | Server handler + client validation    |
| At-least-one cadence   | `cadence_km IS NOT NULL OR cadence_days IS NOT NULL`       | DB table CHECK + client form logic    |
| Soft-delete consistency| exports / math exclude `deleted_at IS NOT NULL`             | Application layer                     |

## Non-goals (v1)

- **Fleet / multi-tenant ownership** beyond single `user_id` per row. Out of scope; the schema is compatible with a future `team_id` addition but we don't add the column speculatively.
- **Multi-currency per user** — one `currency_code` in `settings`. Fill-ups may be in other currencies (captured per-row); trend math splits by currency.
- **Historical make/model catalog** — free-text suffices.
- **Tire/wheel detail tables** — listed in brief v1 scope but as UX fields; their canonical table design is a UX-spec follow-up.

## Critical gaps / risks

- **Single shared `row_version` sequence** is a potential write hotspot as concurrency grows. Per [ADR 002 consequences](adr/002-backup-sync-layer.md#consequences), acceptable for v1 single-user backup; revisit for v1.x live sync.
- **VIN uniqueness** is deliberately **not** enforced. Duplicates are possible across users (fine) and rare within a user (typically user typo); surface through UI validation, not DB constraint.
- **Currency normalization for charts** — stored per-row; charts render one series per currency. Documented in [`consumption-math.md`](consumption-math.md).
- **Non-2-decimal currencies** (JPY, BHD) are out of v1. The `cents` column name is loose — we'll treat it as "minor units × 100" and document the assumption in [`si-units.md`](si-units.md). Formal fix goes on the v1.x list.

## References

- [ADR 001 — Backend / API boundary](adr/001-backend-api-boundary.md)
- [ADR 002 — Backup / sync layer](adr/002-backup-sync-layer.md)
- [`sync-protocol.md`](sync-protocol.md) — wire-level protocol
- [`si-units.md`](si-units.md) — canonical storage
- [`consumption-math.md`](consumption-math.md) — math consuming these columns
- [`photo-pipeline.md`](photo-pipeline.md) — client-only `photo_refs`
- [`export-v1.md`](export-v1.md) — CSV schema derived from these tables
