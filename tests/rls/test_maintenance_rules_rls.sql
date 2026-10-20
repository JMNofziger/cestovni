-- RLS matrix for maintenance_rules. cadence_m (not cadence_km).

\set ON_ERROR_STOP on
\echo 'maintenance_rules: anon cannot read or update'

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM maintenance_rules LIMIT 1;
  RAISE EXCEPTION 'anon SELECT should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
DO $$
BEGIN
  UPDATE maintenance_rules SET notes = 'x' WHERE false;
  RAISE EXCEPTION 'anon UPDATE should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
ROLLBACK;

\echo 'maintenance_rules: ownership matrix as cestovni_app'

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
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa21',
  'Car A',
  'gasoline'
);
INSERT INTO maintenance_rules (
  id, user_id, mutation_id, vehicle_id, name, cadence_m
) VALUES (
  'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1',
  auth_user_id(),
  'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0e1',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'Oil change',
  10000000
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_rules;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own read: expected 1, got %', n;
  END IF;
END;
$$;

SELECT set_config('app.user_id', '22222222-2222-4222-8222-222222222222', true);
INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  auth_user_id(),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb22',
  'Car B',
  'diesel'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_rules;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user read: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  UPDATE maintenance_rules
     SET name = 'Hijacked'
   WHERE id = 'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user update: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  DELETE FROM maintenance_rules WHERE id = 'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1';
  RAISE EXCEPTION 'cross-user delete: expected permission denied (no DELETE grant)';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

INSERT INTO maintenance_rules (
  id, user_id, mutation_id, vehicle_id, name, cadence_days
) VALUES (
  'e0e0e0e0-e0e0-40e0-80e0-e0e0e0e0e0e2',
  auth_user_id(),
  'e0e0e0e0-e0e0-40e0-80e0-e0e0e0e0e0f2',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  'Inspection',
  365
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_rules;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B read after own insert: expected 1, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  INSERT INTO maintenance_rules (
    id, user_id, mutation_id, vehicle_id, name, cadence_m
  ) VALUES (
    'f0f0f0f0-f0f0-40f0-80f0-f0f0f0f0f0f3',
    '11111111-1111-4111-8111-111111111111',
    'f0f0f0f0-f0f0-40f0-80f0-f0f0f0f0f003',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    'Stolen rule',
    5000
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
  SELECT count(*) INTO n FROM maintenance_rules;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user A must not see user B rule: expected 1, got %', n;
  END IF;
  UPDATE maintenance_rules
     SET notes = 'amended'
   WHERE id = 'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own update: expected 1, got %', n;
  END IF;
  SELECT notes INTO seen FROM maintenance_rules
   WHERE id = 'd0d0d0d0-d0d0-40d0-80d0-d0d0d0d0d0d1';
  IF seen <> 'amended' THEN
    RAISE EXCEPTION 'own update did not stick (notes=%)', seen;
  END IF;
END;
$$;

ROLLBACK;
