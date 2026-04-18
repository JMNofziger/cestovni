-- v1 smoke fixture.
--
-- Minimal but non-trivial snapshot of a v1 client DB: one vehicle, one
-- fill-up, one open draft. Every physical quantity is stored in
-- canonical units per si-units.md:
--
--   * volume         -> microliters  (µL)
--   * distance       -> meters       (m)
--   * money          -> cents
--
-- Human sanity check:
--   42.5 L fill-up  -> 42_500_000 µL
--   12 345 km trip  -> 12_345_000 m
--   € 59.12 total   -> 5_912       cents
--
-- Protocol columns (ADR 002) carry server-assigned values (row_version
-- 42, mutation_id) to represent a row that has already been hydrated
-- from a /mutations response.

INSERT INTO vehicles
  (id, user_id, row_version, updated_at, mutation_id,
   name, make, model, year, fuel_type, tank_capacity_uL)
VALUES
  ('00000000-0000-4000-8000-000000000001',
   '00000000-0000-4000-8000-0000000000aa',
   42,
   '2026-04-17T12:00:00Z',
   '00000000-0000-4000-8000-0000000000b1',
   'Škoda Octavia', 'Škoda', 'Octavia', 2016, 'gasoline',
   50000000);

INSERT INTO fill_ups
  (id, user_id, row_version, updated_at, mutation_id,
   vehicle_id, filled_at, odometer_m, volume_uL,
   total_price_cents, currency_code, is_full, missed_before, odometer_reset)
VALUES
  ('00000000-0000-4000-8000-000000000101',
   '00000000-0000-4000-8000-0000000000aa',
   43,
   '2026-04-17T12:30:00Z',
   '00000000-0000-4000-8000-0000000000b2',
   '00000000-0000-4000-8000-000000000001',
   '2026-04-17T12:30:00Z',
   12345000,  -- 12 345 km in m
   42500000,  -- 42.5 L in µL
   5912,      -- € 59.12 in cents
   'EUR', 1, 0, 0);

-- Client-only draft the user started but has not yet promoted. Carries
-- no protocol columns — drafts are local-only (data-model.md).
INSERT INTO drafts
  (id, vehicle_id, created_at)
VALUES
  ('00000000-0000-4000-8000-000000000201',
   '00000000-0000-4000-8000-000000000001',
   '2026-04-17T13:00:00Z');
