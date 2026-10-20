-- RLS matrix for settings, plus the CES-49 CHECK
-- (user_id IS NULL OR id = user_id). id equals the user uuid.

\set ON_ERROR_STOP on
\echo 'settings: anon cannot read or update'

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM settings LIMIT 1;
  RAISE EXCEPTION 'anon SELECT should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
DO $$
BEGIN
  UPDATE settings SET timezone = 'UTC' WHERE false;
  RAISE EXCEPTION 'anon UPDATE should be denied';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;
ROLLBACK;

\echo 'settings: ownership matrix as cestovni_app'

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

-- CHECK parity: user_id matches the session, but id does not.
DO $$
BEGIN
  INSERT INTO settings (
    id, user_id, mutation_id,
    preferred_distance_unit, preferred_volume_unit, currency_code, timezone
  ) VALUES (
    '33333333-3333-4333-8333-333333333333',
    auth_user_id(),
    '33333333-3333-4333-8333-333333333301',
    'km', 'L', 'EUR', 'UTC'
  );
  RAISE EXCEPTION 'settings CHECK should reject id <> user_id';
EXCEPTION
  WHEN check_violation THEN
    NULL;
END;
$$;

INSERT INTO settings (
  id, user_id, mutation_id,
  preferred_distance_unit, preferred_volume_unit, currency_code, timezone
) VALUES (
  auth_user_id(),
  auth_user_id(),
  '11111111-1111-4111-8111-111111111101',
  'km', 'L', 'EUR', 'Europe/Prague'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM settings;
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
  SELECT count(*) INTO n FROM settings;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user read: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
DECLARE
  n int;
BEGIN
  UPDATE settings
     SET timezone = 'UTC'
   WHERE id = '11111111-1111-4111-8111-111111111111';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN
    RAISE EXCEPTION 'cross-user update: expected 0, got %', n;
  END IF;
END;
$$;

DO $$
BEGIN
  DELETE FROM settings WHERE id = '11111111-1111-4111-8111-111111111111';
  RAISE EXCEPTION 'cross-user delete: expected permission denied (no DELETE grant)';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

-- Invalid ownership: id = user_id so the CHECK passes, but that user is
-- neither A (already inserted) nor the session (B). A fresh pair avoids
-- the primary key colliding with A's row and masking the RLS error.
DO $$
BEGIN
  INSERT INTO settings (
    id, user_id, mutation_id,
    preferred_distance_unit, preferred_volume_unit, currency_code, timezone
  ) VALUES (
    '44444444-4444-4444-8444-444444444444',
    '44444444-4444-4444-8444-444444444444',
    '44444444-4444-4444-8444-444444444401',
    'mi', 'gal', 'USD', 'UTC'
  );
  RAISE EXCEPTION 'invalid ownership insert should be rejected';
EXCEPTION
  WHEN insufficient_privilege THEN
    NULL;
END;
$$;

INSERT INTO settings (
  id, user_id, mutation_id,
  preferred_distance_unit, preferred_volume_unit, currency_code, timezone
) VALUES (
  auth_user_id(),
  auth_user_id(),
  '22222222-2222-4222-8222-222222222201',
  'mi', 'gal', 'USD', 'America/New_York'
);

DO $$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n FROM settings;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user B read after own insert: expected 1, got %', n;
  END IF;
END;
$$;

SELECT set_config('app.user_id', '11111111-1111-4111-8111-111111111111', true);

DO $$
DECLARE
  n int;
  seen text;
BEGIN
  SELECT count(*) INTO n FROM settings;
  IF n <> 1 THEN
    RAISE EXCEPTION 'user A must not see user B settings: expected 1, got %', n;
  END IF;
  UPDATE settings
     SET timezone = 'Europe/Berlin'
   WHERE id = auth_user_id();
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'own update: expected 1, got %', n;
  END IF;
  SELECT timezone INTO seen FROM settings WHERE id = auth_user_id();
  IF seen <> 'Europe/Berlin' THEN
    RAISE EXCEPTION 'own update did not stick (timezone=%)', seen;
  END IF;
END;
$$;

ROLLBACK;
