-- RLS matrix for maintenance_events. rule_id stays NULL (one-off event);
-- the FK column is still present and nullable per data-model.md.

\set ON_ERROR_STOP on
\echo 'maintenance_events: anon cannot read or update'

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM maintenance_events LIMIT 1;
  RAISE EXCEPTION 'anon SELECT should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
DO $$
BEGIN
  UPDATE maintenance_events SET notes = 'x' WHERE false;
  RAISE EXCEPTION 'anon UPDATE should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
ROLLBACK;

\echo 'maintenance_events: ownership matrix as cestovni_app'

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
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa31',
  'Car A',
  'gasoline'
);
INSERT INTO maintenance_events (
  id, user_id, mutation_id, vehicle_id, performed_at,
  cost_cents, currency_code, category
) VALUES (
  'abababab-abab-4aba-8aba-abababababa1',
  auth_user_id(),
  'abababab-abab-4aba-8aba-abababababb1',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '2026-04-03T00:00:00Z',
  4500,
  'EUR',
  'oil'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_events;
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
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb32',
  'Car B',
  'diesel'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_events;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user read: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  UPDATE maintenance_events
     SET shop = 'Hijacked'
   WHERE id = 'abababab-abab-4aba-8aba-abababababa1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user update: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  DELETE FROM maintenance_events
   WHERE id = 'abababab-abab-4aba-8aba-abababababa1';
  RAISE EXCEPTION 'cross-user delete: expected permission denied (no DELETE grant)';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

INSERT INTO maintenance_events (
  id, user_id, mutation_id, vehicle_id, performed_at,
  cost_cents, currency_code, category
) VALUES (
  'bcbcbcbc-bcbc-4bcb-8bcb-bcbcbcbcbcb2',
  auth_user_id(),
  'bcbcbcbc-bcbc-4bcb-8bcb-bcbcbcbcbcc2',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  '2026-06-01T00:00:00Z',
  0,
  'EUR',
  'inspection'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM maintenance_events;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B read after own insert: expected 1, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  INSERT INTO maintenance_events (
    id, user_id, mutation_id, vehicle_id, performed_at,
    cost_cents, currency_code, category
  ) VALUES (
    'cdcdcdcd-cdcd-4cdc-8cdc-cdcdcdcdcdc3',
    '11111111-1111-4111-8111-111111111111',
    'cdcdcdcd-cdcd-4cdc-8cdc-cdcdcdcdcdd3',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '2026-06-02T00:00:00Z',
    10,
    'EUR',
    'other'
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
  SELECT count(*) INTO n FROM maintenance_events;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user A must not see user B event: expected 1, got %', n;
  END IF;
  UPDATE maintenance_events
     SET shop = 'Local shop'
   WHERE id = 'abababab-abab-4aba-8aba-abababababa1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own update: expected 1, got %', n;
  END IF;
  SELECT shop INTO seen FROM maintenance_events
   WHERE id = 'abababab-abab-4aba-8aba-abababababa1';
  IF seen <> 'Local shop' THEN
    RAISE EXCEPTION 'own update did not stick (shop=%)', seen;
  END IF;
END;
$$;

ROLLBACK;
