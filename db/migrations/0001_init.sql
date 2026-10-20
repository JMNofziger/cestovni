-- CES-42: server schema at the current client shape (post-CES-71 cadence_m,
-- post-CES-49 settings CHECK). One init file because there is no existing
-- server database to migrate. Client history remains 0001–0005 under
-- client/lib/db/. This file matches the backed-up columns at client schema
-- v5. Client v6 (0006_sync_cursors) is local-only and has no server file.
--
-- Apply as a superuser (or another role that can CREATE ROLE) against an
-- empty database. Tables are not re-runnable. Roles are created only if
-- missing, because they are cluster-wide.
--
-- Runtime DML uses role cestovni_app. RLS reads auth_user_id(), which reads
-- the session GUC. CES-43 sets it from the verified JWT sub:
--   SELECT set_config('app.user_id', '<uuid>', true);

-- ---------------------------------------------------------------------------
-- Roles (ADR 001). NOLOGIN: CI and operators SET ROLE from the migration
-- superuser. cestovni_admin is intentionally not created here.
-- ---------------------------------------------------------------------------

-- Roles are cluster-wide. Skip creation when a previous database on this
-- instance already defined them (a fresh CI container still creates them).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cestovni_migrate') THEN
    CREATE ROLE cestovni_migrate NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cestovni_app') THEN
    CREATE ROLE cestovni_app NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
END
$$;

COMMENT ON ROLE cestovni_migrate IS
  'DDL during migrations. Not used at request time.';
COMMENT ON ROLE cestovni_app IS
  'Runtime DML through RLS. SELECT, INSERT, UPDATE only; soft-delete is an UPDATE. No BYPASSRLS.';
COMMENT ON ROLE anon IS
  'Unauthenticated. No table privileges.';

-- ---------------------------------------------------------------------------
-- Shared row_version sequence (ADR 002). One sequence across tables.
-- ---------------------------------------------------------------------------

CREATE SEQUENCE cestovni_row_version_seq AS BIGINT;

-- ---------------------------------------------------------------------------
-- auth_user_id() — CES-43 will wrap this with real JWT verification.
-- SECURITY DEFINER so the GUC read does not depend on the caller owning
-- the setting. search_path is pinned (the body touches only pg_catalog).
-- ---------------------------------------------------------------------------

CREATE FUNCTION auth_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::UUID;
$$;

COMMENT ON FUNCTION auth_user_id() IS
  'Current request user. Stub: NULLIF(current_setting(''app.user_id''), '''')::uuid. CES-43 replaces the token source; the claim shape stays.';

-- Assigns server authority columns on every insert and update.
-- Clients must not supply row_version; this overwrites it.
CREATE FUNCTION cestovni_touch_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  NEW.row_version := nextval('cestovni_row_version_seq');
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Tables. Column names match docs/specs/data-model.md. Mixed-case SI
-- columns are quoted so Postgres preserves volume_uL / tank_capacity_uL
-- (unquoted identifiers would fold to lowercase).
-- ---------------------------------------------------------------------------

CREATE TABLE vehicles (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  row_version BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  mutation_id UUID NOT NULL,
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  make TEXT CHECK (make IS NULL OR length(make) <= 80),
  model TEXT CHECK (model IS NULL OR length(model) <= 80),
  year SMALLINT CHECK (year IS NULL OR year BETWEEN 1900 AND 2100),
  vin TEXT CHECK (vin IS NULL OR length(vin) <= 32),
  fuel_type TEXT NOT NULL CHECK (
    fuel_type IN ('gasoline', 'diesel', 'lpg', 'cng', 'ev_kwh', 'other')
  ),
  "tank_capacity_uL" BIGINT CHECK (
    "tank_capacity_uL" IS NULL OR "tank_capacity_uL" >= 0
  ),
  archived_at TIMESTAMPTZ
);

CREATE TRIGGER vehicles_touch
  BEFORE INSERT OR UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION cestovni_touch_row();

CREATE TABLE fill_ups (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  row_version BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  mutation_id UUID NOT NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles (id),
  filled_at TIMESTAMPTZ NOT NULL,
  odometer_m BIGINT NOT NULL CHECK (odometer_m >= 0),
  "volume_uL" BIGINT NOT NULL CHECK ("volume_uL" >= 0),
  total_price_cents BIGINT NOT NULL CHECK (total_price_cents >= 0),
  currency_code CHAR(3) NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  is_full BOOLEAN NOT NULL,
  missed_before BOOLEAN NOT NULL DEFAULT false,
  odometer_reset BOOLEAN NOT NULL DEFAULT false,
  notes TEXT CHECK (notes IS NULL OR length(notes) <= 500)
);

CREATE TRIGGER fill_ups_touch
  BEFORE INSERT OR UPDATE ON fill_ups
  FOR EACH ROW EXECUTE FUNCTION cestovni_touch_row();

CREATE TABLE maintenance_rules (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  row_version BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  mutation_id UUID NOT NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles (id),
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  cadence_m BIGINT CHECK (cadence_m IS NULL OR cadence_m > 0),
  cadence_days INTEGER CHECK (cadence_days IS NULL OR cadence_days > 0),
  enabled BOOLEAN NOT NULL DEFAULT true,
  notes TEXT CHECK (notes IS NULL OR length(notes) <= 500),
  CHECK (cadence_m IS NOT NULL OR cadence_days IS NOT NULL)
);

CREATE TRIGGER maintenance_rules_touch
  BEFORE INSERT OR UPDATE ON maintenance_rules
  FOR EACH ROW EXECUTE FUNCTION cestovni_touch_row();

CREATE TABLE maintenance_events (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  row_version BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  mutation_id UUID NOT NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles (id),
  rule_id UUID REFERENCES maintenance_rules (id),
  performed_at TIMESTAMPTZ NOT NULL,
  odometer_m BIGINT CHECK (odometer_m IS NULL OR odometer_m >= 0),
  cost_cents BIGINT NOT NULL DEFAULT 0 CHECK (cost_cents >= 0),
  currency_code CHAR(3) NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  category TEXT NOT NULL DEFAULT 'other' CHECK (
    category IN (
      'oil', 'tires', 'brakes', 'inspection', 'battery', 'fluid', 'other'
    )
  ),
  shop TEXT CHECK (shop IS NULL OR length(shop) BETWEEN 1 AND 120),
  notes TEXT CHECK (notes IS NULL OR length(notes) <= 500)
);

CREATE TRIGGER maintenance_events_touch
  BEFORE INSERT OR UPDATE ON maintenance_events
  FOR EACH ROW EXECUTE FUNCTION cestovni_touch_row();

CREATE TABLE settings (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  row_version BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  mutation_id UUID NOT NULL,
  preferred_distance_unit TEXT NOT NULL CHECK (
    preferred_distance_unit IN ('km', 'mi')
  ),
  preferred_volume_unit TEXT NOT NULL CHECK (
    preferred_volume_unit IN ('L', 'gal')
  ),
  currency_code CHAR(3) NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
  timezone TEXT NOT NULL CHECK (length(timezone) BETWEEN 1 AND 64),
  default_vehicle_id UUID,
  -- Same shape as the client (migration 0005). On the server user_id is
  -- always written, so this reduces to id = user_id. NULL stays in the
  -- predicate for parity with the on-device pre-sync row.
  CHECK (user_id IS NULL OR id = user_id)
);

CREATE TRIGGER settings_touch
  BEFORE INSERT OR UPDATE ON settings
  FOR EACH ROW EXECUTE FUNCTION cestovni_touch_row();

-- ---------------------------------------------------------------------------
-- Indexes (data-model.md). Partial indexes cover the live-row hot path.
-- ---------------------------------------------------------------------------

CREATE INDEX vehicles_user_id_idx ON vehicles (user_id);
CREATE INDEX vehicles_user_live_idx ON vehicles (user_id) WHERE deleted_at IS NULL;
CREATE INDEX vehicles_row_version_idx ON vehicles (row_version);

CREATE INDEX fill_ups_user_vehicle_time_idx
  ON fill_ups (user_id, vehicle_id, filled_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX fill_ups_user_row_version_idx ON fill_ups (user_id, row_version);
CREATE INDEX fill_ups_vehicle_id_idx ON fill_ups (vehicle_id);

CREATE INDEX maintenance_rules_user_vehicle_idx
  ON maintenance_rules (user_id, vehicle_id)
  WHERE deleted_at IS NULL;
CREATE INDEX maintenance_rules_user_row_version_idx
  ON maintenance_rules (user_id, row_version);

CREATE INDEX maintenance_events_user_vehicle_time_idx
  ON maintenance_events (user_id, vehicle_id, performed_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX maintenance_events_user_row_version_idx
  ON maintenance_events (user_id, row_version);

CREATE UNIQUE INDEX settings_user_id_uidx ON settings (user_id);
CREATE INDEX settings_row_version_idx ON settings (row_version);

-- ---------------------------------------------------------------------------
-- RLS. Two permissive policies per table (CES-42 locked decision):
--   <table>_select_own  FOR SELECT USING (user_id = auth_user_id())
--   <table>_modify_own  FOR ALL    USING + WITH CHECK (same predicate)
-- FORCE so the table owner does not silently bypass. Superuser and
-- BYPASSRLS still bypass; cestovni_app has neither.
-- No DELETE grant: FOR ALL's DELETE arm is unreachable for cestovni_app.
-- Soft-delete is UPDATE of deleted_at.
-- ---------------------------------------------------------------------------

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles FORCE ROW LEVEL SECURITY;
CREATE POLICY vehicles_select_own ON vehicles
  FOR SELECT USING (user_id = auth_user_id());
CREATE POLICY vehicles_modify_own ON vehicles
  FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

ALTER TABLE fill_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE fill_ups FORCE ROW LEVEL SECURITY;
CREATE POLICY fill_ups_select_own ON fill_ups
  FOR SELECT USING (user_id = auth_user_id());
CREATE POLICY fill_ups_modify_own ON fill_ups
  FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

ALTER TABLE maintenance_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_rules FORCE ROW LEVEL SECURITY;
CREATE POLICY maintenance_rules_select_own ON maintenance_rules
  FOR SELECT USING (user_id = auth_user_id());
CREATE POLICY maintenance_rules_modify_own ON maintenance_rules
  FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

ALTER TABLE maintenance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_events FORCE ROW LEVEL SECURITY;
CREATE POLICY maintenance_events_select_own ON maintenance_events
  FOR SELECT USING (user_id = auth_user_id());
CREATE POLICY maintenance_events_modify_own ON maintenance_events
  FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings FORCE ROW LEVEL SECURITY;
CREATE POLICY settings_select_own ON settings
  FOR SELECT USING (user_id = auth_user_id());
CREATE POLICY settings_modify_own ON settings
  FOR ALL
  USING (user_id = auth_user_id())
  WITH CHECK (user_id = auth_user_id());

-- ---------------------------------------------------------------------------
-- Ownership + grants. Migration role owns objects. Runtime role gets DML
-- only. anon keeps nothing.
-- ---------------------------------------------------------------------------

ALTER SEQUENCE cestovni_row_version_seq OWNER TO cestovni_migrate;
ALTER FUNCTION auth_user_id() OWNER TO cestovni_migrate;
ALTER FUNCTION cestovni_touch_row() OWNER TO cestovni_migrate;

ALTER TABLE vehicles OWNER TO cestovni_migrate;
ALTER TABLE fill_ups OWNER TO cestovni_migrate;
ALTER TABLE maintenance_rules OWNER TO cestovni_migrate;
ALTER TABLE maintenance_events OWNER TO cestovni_migrate;
ALTER TABLE settings OWNER TO cestovni_migrate;

REVOKE ALL ON TABLE
  vehicles, fill_ups, maintenance_rules, maintenance_events, settings
  FROM PUBLIC;
REVOKE ALL ON SEQUENCE cestovni_row_version_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION auth_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION cestovni_touch_row() FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON TABLE
  vehicles, fill_ups, maintenance_rules, maintenance_events, settings
  TO cestovni_app;
GRANT USAGE, SELECT ON SEQUENCE cestovni_row_version_seq TO cestovni_app;
GRANT EXECUTE ON FUNCTION auth_user_id() TO cestovni_app;
GRANT EXECUTE ON FUNCTION cestovni_touch_row() TO cestovni_app;
