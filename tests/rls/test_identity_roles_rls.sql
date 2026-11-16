-- CES-80 identity roles. Rolls back. Expects ON_ERROR_STOP from the caller.
-- User A 11111111-1111-4111-8111-111111111111
-- User B 22222222-2222-4222-8222-222222222222
-- Product tables have no foreign key to users. Purge uses the existing
-- policies (no TO clause) plus SELECT, DELETE grants.

\set ON_ERROR_STOP on

\echo 'identity: structure, ownership, and grant matrix'

DO $$
DECLARE
  expected text[] := ARRAY[
    'auth_login_transactions',
    'auth_oauth_states',
    'auth_refresh_tokens',
    'auth_sessions',
    'users'
  ];
  present text[];
  tbl text;
  owner name;
  rls boolean;
  n int;
  role_name text;
  flags record;
  ident text[] := ARRAY[
    'users',
    'auth_sessions',
    'auth_refresh_tokens',
    'auth_oauth_states',
    'auth_login_transactions'
  ];
  prod text[] := ARRAY[
    'vehicles',
    'fill_ups',
    'maintenance_rules',
    'maintenance_events',
    'settings'
  ];
  dml text[] := ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
  priv text;
BEGIN
  SELECT coalesce(array_agg(c.relname::text ORDER BY c.relname), ARRAY[]::text[])
    INTO present
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND (c.relname = 'users' OR c.relname LIKE 'auth\_%' ESCAPE '\');

  IF present IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'identity tables are %, expected %', present, expected;
  END IF;

  FOREACH tbl IN ARRAY expected LOOP
    SELECT pg_get_userbyid(c.relowner), c.relrowsecurity
      INTO owner, rls
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname = tbl;
    IF owner IS DISTINCT FROM 'cestovni_migrate' THEN
      RAISE EXCEPTION '% owner is %', tbl, owner;
    END IF;
    IF rls IS DISTINCT FROM false THEN
      RAISE EXCEPTION '% relrowsecurity is %', tbl, rls;
    END IF;
  END LOOP;

  SELECT count(*) INTO n
  FROM pg_constraint con
  JOIN pg_class child ON child.oid = con.conrelid
  JOIN pg_namespace ns ON ns.oid = child.relnamespace
  JOIN pg_class parent ON parent.oid = con.confrelid
  WHERE con.contype = 'f'
    AND ns.nspname = 'public'
    AND child.relname IN (
      'vehicles', 'fill_ups', 'maintenance_rules', 'maintenance_events', 'settings'
    )
    AND parent.relname = 'users';
  IF n <> 0 THEN
    RAISE EXCEPTION 'product tables have % foreign keys to users', n;
  END IF;

  FOREACH role_name IN ARRAY ARRAY['cestovni_auth', 'cestovni_purge'] LOOP
    SELECT rolcanlogin, rolsuper, rolbypassrls
      INTO flags
    FROM pg_roles
    WHERE rolname = role_name;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'role % is missing', role_name;
    END IF;
    IF flags.rolcanlogin OR flags.rolsuper OR flags.rolbypassrls THEN
      RAISE EXCEPTION '% flags login=% super=% bypass=%',
        role_name, flags.rolcanlogin, flags.rolsuper, flags.rolbypassrls;
    END IF;
  END LOOP;

  FOREACH tbl IN ARRAY ident LOOP
    FOREACH priv IN ARRAY dml LOOP
      IF has_table_privilege('cestovni_app', tbl, priv) THEN
        RAISE EXCEPTION 'cestovni_app has % on %', priv, tbl;
      END IF;
      IF NOT has_table_privilege('cestovni_auth', tbl, priv) THEN
        RAISE EXCEPTION 'cestovni_auth missing % on %', priv, tbl;
      END IF;
      IF has_table_privilege('cestovni_purge', tbl, priv) THEN
        RAISE EXCEPTION 'cestovni_purge has % on %', priv, tbl;
      END IF;
    END LOOP;
  END LOOP;

  FOREACH tbl IN ARRAY prod LOOP
    FOREACH priv IN ARRAY dml LOOP
      IF has_table_privilege('cestovni_auth', tbl, priv) THEN
        RAISE EXCEPTION 'cestovni_auth has % on %', priv, tbl;
      END IF;
    END LOOP;
    IF NOT has_table_privilege('cestovni_purge', tbl, 'SELECT') THEN
      RAISE EXCEPTION 'cestovni_purge missing SELECT on %', tbl;
    END IF;
    IF NOT has_table_privilege('cestovni_purge', tbl, 'DELETE') THEN
      RAISE EXCEPTION 'cestovni_purge missing DELETE on %', tbl;
    END IF;
    IF has_table_privilege('cestovni_purge', tbl, 'INSERT') THEN
      RAISE EXCEPTION 'cestovni_purge has INSERT on %', tbl;
    END IF;
    IF has_table_privilege('cestovni_purge', tbl, 'UPDATE') THEN
      RAISE EXCEPTION 'cestovni_purge has UPDATE on %', tbl;
    END IF;
    IF has_table_privilege('cestovni_purge', tbl, 'TRUNCATE') THEN
      RAISE EXCEPTION 'cestovni_purge has TRUNCATE on %', tbl;
    END IF;
  END LOOP;

  IF has_function_privilege('cestovni_auth', 'auth_user_id()', 'EXECUTE') THEN
    RAISE EXCEPTION 'cestovni_auth can execute auth_user_id()';
  END IF;
  IF NOT has_function_privilege('cestovni_purge', 'auth_user_id()', 'EXECUTE') THEN
    RAISE EXCEPTION 'cestovni_purge cannot execute auth_user_id()';
  END IF;
END;
$$;

\echo 'identity: cestovni_app is denied on every identity table'

BEGIN;
SET LOCAL ROLE cestovni_app;
DO $$
DECLARE
  tbl text;
  kind text;
  stmt text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'users',
    'auth_sessions',
    'auth_refresh_tokens',
    'auth_oauth_states',
    'auth_login_transactions'
  ] LOOP
    FOREACH kind IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'] LOOP
      stmt := CASE kind
        WHEN 'SELECT' THEN format('SELECT 1 FROM %I LIMIT 0', tbl)
        WHEN 'INSERT' THEN format('INSERT INTO %I DEFAULT VALUES', tbl)
        WHEN 'UPDATE' THEN format('UPDATE %I SET created_at = created_at WHERE false', tbl)
        WHEN 'DELETE' THEN format('DELETE FROM %I WHERE false', tbl)
      END;
      BEGIN
        EXECUTE stmt;
        RAISE EXCEPTION 'cestovni_app % on % should be denied', kind, tbl;
      EXCEPTION
        WHEN insufficient_privilege THEN
          IF SQLSTATE IS DISTINCT FROM '42501' THEN
            RAISE EXCEPTION 'cestovni_app % on % SQLSTATE %', kind, tbl, SQLSTATE;
          END IF;
      END;
    END LOOP;
  END LOOP;
END;
$$;
ROLLBACK;

\echo 'identity: cestovni_auth is denied on every product table'

BEGIN;
SET LOCAL ROLE cestovni_auth;
DO $$
DECLARE
  tbl text;
  kind text;
  stmt text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'vehicles',
    'fill_ups',
    'maintenance_rules',
    'maintenance_events',
    'settings'
  ] LOOP
    FOREACH kind IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'] LOOP
      stmt := CASE kind
        WHEN 'SELECT' THEN format('SELECT 1 FROM %I LIMIT 0', tbl)
        WHEN 'INSERT' THEN format('INSERT INTO %I DEFAULT VALUES', tbl)
        WHEN 'UPDATE' THEN format('UPDATE %I SET user_id = user_id WHERE false', tbl)
        WHEN 'DELETE' THEN format('DELETE FROM %I WHERE false', tbl)
      END;
      BEGIN
        EXECUTE stmt;
        RAISE EXCEPTION 'cestovni_auth % on % should be denied', kind, tbl;
      EXCEPTION
        WHEN insufficient_privilege THEN
          IF SQLSTATE IS DISTINCT FROM '42501' THEN
            RAISE EXCEPTION 'cestovni_auth % on % SQLSTATE %', kind, tbl, SQLSTATE;
          END IF;
      END;
    END LOOP;
  END LOOP;
END;
$$;
ROLLBACK;

\echo 'identity: cestovni_auth writes, duplicate google_sub, cascade delete'

BEGIN;
SET LOCAL ROLE cestovni_auth;

INSERT INTO users (google_sub) VALUES ('google-sub-ces80');

DO $$
DECLARE
  uid uuid;
  em text;
BEGIN
  SELECT id, email INTO uid, em FROM users WHERE google_sub = 'google-sub-ces80';
  IF uid IS NULL THEN
    RAISE EXCEPTION 'users.id was not allocated';
  END IF;
  IF em IS NOT NULL THEN
    RAISE EXCEPTION 'email should be null on insert, got %', em;
  END IF;
END;
$$;

INSERT INTO auth_sessions (user_id, expires_at)
SELECT id, timestamptz '2030-01-01' FROM users WHERE google_sub = 'google-sub-ces80';

INSERT INTO auth_refresh_tokens (session_id, token_hash, expires_at)
SELECT s.id, decode(repeat('ab', 32), 'hex'), timestamptz '2030-01-01'
FROM auth_sessions s
JOIN users u ON u.id = s.user_id
WHERE u.google_sub = 'google-sub-ces80';

INSERT INTO auth_oauth_states (state_hash, code_verifier, client, nonce, expires_at)
VALUES (
  decode(repeat('cd', 32), 'hex'),
  repeat('v', 43),
  'android',
  'nonce-1',
  timestamptz '2030-01-01'
);

INSERT INTO auth_login_transactions (code_hash, google_sub, expires_at)
VALUES (
  decode(repeat('ef', 32), 'hex'),
  'google-sub-ces80',
  timestamptz '2030-01-01'
);

UPDATE users SET email = 'person@example.com' WHERE google_sub = 'google-sub-ces80';
UPDATE auth_sessions SET last_used_at = timestamptz '2030-01-02'
WHERE user_id = (SELECT id FROM users WHERE google_sub = 'google-sub-ces80');
UPDATE auth_refresh_tokens SET used_at = timestamptz '2030-01-02'
WHERE token_hash = decode(repeat('ab', 32), 'hex');
UPDATE auth_oauth_states SET nonce = 'nonce-2'
WHERE state_hash = decode(repeat('cd', 32), 'hex');
UPDATE auth_login_transactions SET consumed_at = timestamptz '2030-01-02'
WHERE code_hash = decode(repeat('ef', 32), 'hex');

DO $$
BEGIN
  INSERT INTO users (google_sub) VALUES ('google-sub-ces80');
  RAISE EXCEPTION 'duplicate google_sub should raise 23505';
EXCEPTION
  WHEN unique_violation THEN
    IF SQLSTATE IS DISTINCT FROM '23505' THEN
      RAISE EXCEPTION 'duplicate google_sub SQLSTATE %', SQLSTATE;
    END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM auth_sessions;
  IF n <> 1 THEN
    RAISE EXCEPTION 'expected 1 session before delete, got %', n;
  END IF;
  SELECT count(*) INTO n FROM auth_refresh_tokens;
  IF n <> 1 THEN
    RAISE EXCEPTION 'expected 1 refresh token before delete, got %', n;
  END IF;
END;
$$;

DELETE FROM users WHERE google_sub = 'google-sub-ces80';

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM auth_sessions;
  IF n <> 0 THEN
    RAISE EXCEPTION 'session cascade left %', n;
  END IF;
  SELECT count(*) INTO n FROM auth_refresh_tokens;
  IF n <> 0 THEN
    RAISE EXCEPTION 'refresh token cascade left %', n;
  END IF;
END;
$$;
ROLLBACK;

\echo 'identity: cestovni_purge deletes only the current user'

BEGIN;
SET LOCAL ROLE cestovni_app;
SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  auth_user_id(),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa81',
  'Car A',
  'gasoline'
);
INSERT INTO fill_ups (
  id, user_id, mutation_id, vehicle_id, filled_at,
  odometer_m, "volume_uL", total_price_cents, currency_code, is_full, notes
) VALUES (
  'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1',
  auth_user_id(),
  'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a081',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '2026-04-17T12:30:00Z',
  12345000,
  42100000,
  5912,
  'EUR',
  true,
  'fill-a'
);
UPDATE fill_ups
   SET deleted_at = now()
 WHERE id = 'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1';
INSERT INTO maintenance_rules (
  id, user_id, mutation_id, vehicle_id, name, cadence_m
) VALUES (
  'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1',
  auth_user_id(),
  'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d081',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'Oil A',
  10000000
);
INSERT INTO maintenance_events (
  id, user_id, mutation_id, vehicle_id, rule_id, performed_at,
  cost_cents, currency_code, category, shop
) VALUES (
  'e0e0e0e0-e0e0-40e0-80e0-e0e0e0e0e0e1',
  auth_user_id(),
  'e0e0e0e0-e0e0-40e0-80e0-e0e0e0e0e081',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1',
  '2026-04-03T00:00:00Z',
  4500,
  'EUR',
  'oil',
  'Shop A'
);
INSERT INTO settings (
  id, user_id, mutation_id,
  preferred_distance_unit, preferred_volume_unit, currency_code, timezone
) VALUES (
  auth_user_id(),
  auth_user_id(),
  '11111111-1111-4111-8111-111111111181',
  'km', 'L', 'EUR', 'Europe/Belgrade'
);

SELECT set_config('app.user_id', '22222222-2222-4222-8222-222222222222', true);

INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  auth_user_id(),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb82',
  'Car B',
  'diesel'
);
INSERT INTO fill_ups (
  id, user_id, mutation_id, vehicle_id, filled_at,
  odometer_m, "volume_uL", total_price_cents, currency_code, is_full, notes
) VALUES (
  'b0b0b0b0-b0b0-40b0-80b0-b0b0b0b0b0b2',
  auth_user_id(),
  'b0b0b0b0-b0b0-40b0-80b0-b0b0b0b0b082',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  '2026-04-18T12:30:00Z',
  20000000,
  30000000,
  4000,
  'EUR',
  true,
  'fill-b'
);
INSERT INTO maintenance_rules (
  id, user_id, mutation_id, vehicle_id, name, cadence_m
) VALUES (
  'd1d1d1d1-d1d1-41d1-81d1-d1d1d1d1d1d2',
  auth_user_id(),
  'd1d1d1d1-d1d1-41d1-81d1-d1d1d1d1d182',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  'Oil B',
  10000000
);
INSERT INTO maintenance_events (
  id, user_id, mutation_id, vehicle_id, rule_id, performed_at,
  cost_cents, currency_code, category, shop
) VALUES (
  'e1e1e1e1-e1e1-41e1-81e1-e1e1e1e1e1e2',
  auth_user_id(),
  'e1e1e1e1-e1e1-41e1-81e1-e1e1e1e1e182',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  'd1d1d1d1-d1d1-41d1-81d1-d1d1d1d1d1d2',
  '2026-04-04T00:00:00Z',
  4500,
  'EUR',
  'oil',
  'Shop B'
);
INSERT INTO settings (
  id, user_id, mutation_id,
  preferred_distance_unit, preferred_volume_unit, currency_code, timezone
) VALUES (
  auth_user_id(),
  auth_user_id(),
  '22222222-2222-4222-8222-222222222282',
  'km', 'L', 'EUR', 'Europe/Prague'
);

RESET ROLE;
SET LOCAL ROLE cestovni_purge;
SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'vehicles', 'fill_ups', 'maintenance_rules', 'maintenance_events', 'settings'
  ] LOOP
    BEGIN
      EXECUTE format(
        'INSERT INTO %I DEFAULT VALUES',
        tbl
      );
      RAISE EXCEPTION 'cestovni_purge INSERT on % should be denied', tbl;
    EXCEPTION
      WHEN insufficient_privilege THEN
        IF SQLSTATE IS DISTINCT FROM '42501' THEN
          RAISE EXCEPTION 'purge INSERT % SQLSTATE %', tbl, SQLSTATE;
        END IF;
    END;
    BEGIN
      EXECUTE format('UPDATE %I SET user_id = user_id WHERE false', tbl);
      RAISE EXCEPTION 'cestovni_purge UPDATE on % should be denied', tbl;
    EXCEPTION
      WHEN insufficient_privilege THEN
        IF SQLSTATE IS DISTINCT FROM '42501' THEN
          RAISE EXCEPTION 'purge UPDATE % SQLSTATE %', tbl, SQLSTATE;
        END IF;
    END;
  END LOOP;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM vehicles;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge sees % vehicles, expected 1', n;
  END IF;
  SELECT count(*) INTO n FROM fill_ups;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge sees % fill_ups, expected 1', n;
  END IF;
  SELECT count(*) INTO n FROM fill_ups WHERE deleted_at IS NOT NULL;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge should see the soft-deleted fill-up, got %', n;
  END IF;
  SELECT count(*) INTO n FROM maintenance_rules;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge sees % rules, expected 1', n;
  END IF;
  SELECT count(*) INTO n FROM maintenance_events;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge sees % events, expected 1', n;
  END IF;
  SELECT count(*) INTO n FROM settings;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge sees % settings, expected 1', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'maintenance_events', 'maintenance_rules', 'fill_ups', 'vehicles', 'settings'
  ] LOOP
    EXECUTE format(
      'DELETE FROM %I WHERE user_id = %L',
      tbl,
      '22222222-2222-4222-8222-222222222222'
    );
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN
      RAISE EXCEPTION 'delete aimed at user B on % affected %', tbl, n;
    END IF;
  END LOOP;
END;
$$;

SELECT set_config('app.user_id', '', true);

DO $$
DECLARE
  n int;
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'maintenance_events', 'maintenance_rules', 'fill_ups', 'vehicles', 'settings'
  ] LOOP
    EXECUTE format('DELETE FROM %I', tbl);
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN
      RAISE EXCEPTION 'delete with app.user_id unset on % affected %', tbl, n;
    END IF;
  END LOOP;
END;
$$;

SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

DO $$
DECLARE
  n int;
BEGIN
  DELETE FROM maintenance_events;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge maintenance_events expected 1, got %', n;
  END IF;
  DELETE FROM maintenance_rules;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge maintenance_rules expected 1, got %', n;
  END IF;
  DELETE FROM fill_ups;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge fill_ups expected 1, got %', n;
  END IF;
  DELETE FROM vehicles;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge vehicles expected 1, got %', n;
  END IF;
  DELETE FROM settings;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'purge settings expected 1, got %', n;
  END IF;
END;
$$;

RESET ROLE;

DO $$
DECLARE
  n int;
  user_a uuid := '11111111-1111-4111-8111-111111111111';
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'vehicles', 'fill_ups', 'maintenance_rules', 'maintenance_events', 'settings'
  ] LOOP
    EXECUTE format('SELECT count(*) FROM %I WHERE user_id = $1', tbl)
      INTO n
      USING user_a;
    IF n <> 0 THEN
      RAISE EXCEPTION 'user A still has % rows in %', n, tbl;
    END IF;
  END LOOP;

  SELECT count(*) INTO n FROM vehicles WHERE user_id = user_b AND name = 'Car B';
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B vehicle missing or changed';
  END IF;
  SELECT count(*) INTO n
  FROM fill_ups
  WHERE user_id = user_b AND notes = 'fill-b' AND deleted_at IS NULL;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B fill-up missing or changed';
  END IF;
  SELECT count(*) INTO n
  FROM maintenance_rules
  WHERE user_id = user_b AND name = 'Oil B';
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B rule missing or changed';
  END IF;
  SELECT count(*) INTO n
  FROM maintenance_events
  WHERE user_id = user_b AND shop = 'Shop B';
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B event missing or changed';
  END IF;
  SELECT count(*) INTO n
  FROM settings
  WHERE user_id = user_b AND id = user_b AND timezone = 'Europe/Prague';
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B settings missing or changed';
  END IF;
END;
$$;
ROLLBACK;
