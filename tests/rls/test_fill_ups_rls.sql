-- RLS matrix for fill_ups. Parent vehicles are seeded as the same user
-- (FK only; vehicles RLS is covered in test_vehicles_rls.sql).

\set ON_ERROR_STOP on
\echo 'fill_ups: anon cannot read or update'

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM fill_ups LIMIT 1;
  RAISE EXCEPTION 'anon SELECT should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
DO $$
BEGIN
  UPDATE fill_ups SET notes = 'x' WHERE false;
  RAISE EXCEPTION 'anon UPDATE should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
ROLLBACK;

\echo 'fill_ups: ownership matrix as cestovni_app'

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

-- Vehicle owned by A.
SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);
INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  auth_user_id(),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11',
  'Car A',
  'gasoline'
);

INSERT INTO fill_ups (
  id, user_id, mutation_id, vehicle_id, filled_at,
  odometer_m, "volume_uL", total_price_cents, currency_code, is_full
) VALUES (
  'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1',
  auth_user_id(),
  'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0b1',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '2026-04-17T12:30:00Z',
  12345000,
  42100000,
  5912,
  'EUR',
  true
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM fill_ups;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own read: expected 1, got %', n;
  END IF;
END;
$$;

-- Vehicle owned by B, then prove B cannot see A's fill-up.
SELECT set_config('app.user_id', '22222222-2222-4222-8222-222222222222', true);
INSERT INTO vehicles (id, user_id, mutation_id, name, fuel_type)
VALUES (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  auth_user_id(),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb12',
  'Car B',
  'diesel'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM fill_ups;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user read: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  UPDATE fill_ups
     SET notes = 'hijacked'
   WHERE id = 'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user update: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  DELETE FROM fill_ups WHERE id = 'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1';
  RAISE EXCEPTION 'cross-user delete: expected permission denied (no DELETE grant)';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

INSERT INTO fill_ups (
  id, user_id, mutation_id, vehicle_id, filled_at,
  odometer_m, "volume_uL", total_price_cents, currency_code, is_full
) VALUES (
  'b0b0b0b0-b0b0-40b0-80b0-b0b0b0b0b0b2',
  auth_user_id(),
  'b0b0b0b0-b0b0-40b0-80b0-b0b0b0b0b0c2',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  '2026-05-01T08:00:00Z',
  20000000,
  35000000,
  4800,
  'EUR',
  true
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM fill_ups;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B read after own insert: expected 1, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  INSERT INTO fill_ups (
    id, user_id, mutation_id, vehicle_id, filled_at,
    odometer_m, "volume_uL", total_price_cents, currency_code, is_full
  ) VALUES (
    'c0c0c0c0-c0c0-40c0-80c0-c0c0c0c0c0c3',
    '11111111-1111-4111-8111-111111111111',
    'c0c0c0c0-c0c0-40c0-80c0-c0c0c0c0c0d3',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '2026-05-02T08:00:00Z',
    21000000,
    1000000,
    100,
    'EUR',
    false
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
  SELECT count(*) INTO n FROM fill_ups;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user A must not see user B fill-up: expected 1, got %', n;
  END IF;
  UPDATE fill_ups
     SET notes = 'amended'
   WHERE id = 'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own update: expected 1, got %', n;
  END IF;
  SELECT notes INTO seen FROM fill_ups
   WHERE id = 'a0a0a0a0-a0a0-40a0-80a0-a0a0a0a0a0a1';
  IF seen <> 'amended' THEN
    RAISE EXCEPTION 'own update did not stick (notes=%)', seen;
  END IF;
END;
$$;

ROLLBACK;
