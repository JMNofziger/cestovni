-- RLS matrix for vehicles. Runs as cestovni_app with SET LOCAL app.user_id.
-- User A 11111111-1111-4111-8111-111111111111
-- User B 22222222-2222-4222-8222-222222222222
-- Rolls back. Expects ON_ERROR_STOP from the caller.

\set ON_ERROR_STOP on
\echo 'vehicles: anon cannot read or update'

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM vehicles LIMIT 1;
  RAISE EXCEPTION 'anon SELECT should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
DO $$
BEGIN
  UPDATE vehicles SET name = 'x' WHERE false;
  RAISE EXCEPTION 'anon UPDATE should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
ROLLBACK;

\echo 'vehicles: ownership matrix as cestovni_app'

BEGIN;
DO $$
DECLARE
  bypass boolean;
BEGIN
  SELECT rolbypassrls INTO bypass FROM pg_roles WHERE rolname = 'cestovni_app';
  IF bypass IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'cestovni_app must not BYPASSRLS (got %)', bypass;
  END IF;
END;
$$;

SET LOCAL ROLE cestovni_app;
SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  auth_user_id(),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
  'Car A',
  'gasoline'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM vehicles;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own read: expected 1, got %', n;
  END IF;
END;
$$;

SELECT set_config('app.user_id', '22222222-2222-4222-8222-222222222222', true);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM vehicles;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user read: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  UPDATE vehicles
     SET name = 'Hijacked'
   WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user update: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  DELETE FROM vehicles WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  RAISE EXCEPTION 'cross-user delete: expected permission denied (no DELETE grant)';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

-- Valid ownership insert.
INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  auth_user_id(),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb02',
  'Car B',
  'diesel'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM vehicles;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B read after own insert: expected 1, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
  VALUES (
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
    '11111111-1111-4111-8111-111111111111',
    'cccccccc-cccc-4ccc-8ccc-cccccccccc03',
    'Stolen',
    'gasoline'
  );
  RAISE EXCEPTION 'invalid ownership insert should be rejected';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

DO $$
DECLARE
  n int;
  seen text;
BEGIN
  SELECT count(*) INTO n FROM vehicles;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user A must not see user B: expected 1, got %', n;
  END IF;
  UPDATE vehicles
     SET name = 'Car A2'
   WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own update: expected 1, got %', n;
  END IF;
  SELECT name INTO seen FROM vehicles
   WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  IF seen <> 'Car A2' THEN
    RAISE EXCEPTION 'own update did not stick (name=%)', seen;
  END IF;
END;
$$;

ROLLBACK;
