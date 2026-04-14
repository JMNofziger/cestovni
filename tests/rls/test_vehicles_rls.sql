-- RLS regression tests for `vehicles` table
-- Scaffold — fill in when data model spec (CES-32) is finalized.
--
-- Prerequisites:
--   - Migrations applied to test DB
--   - Two test users provisioned: test_user_a, test_user_b
--   - RLS enabled on `vehicles` table

-- Setup: insert test data as user A
SET LOCAL role = 'test_user_a';
INSERT INTO vehicles (id, user_id, name) VALUES ('v1', 'user_a_id', 'Car A');

-- Case: allow own read
SET LOCAL role = 'test_user_a';
SELECT count(*) AS own_read FROM vehicles;
-- EXPECT: 1

-- Case: deny cross-user read
SET LOCAL role = 'test_user_b';
SELECT count(*) AS cross_read FROM vehicles;
-- EXPECT: 0

-- Case: deny cross-user update
SET LOCAL role = 'test_user_b';
UPDATE vehicles SET name = 'Hijacked' WHERE id = 'v1';
-- EXPECT: 0 rows affected

-- Case: deny cross-user delete
SET LOCAL role = 'test_user_b';
DELETE FROM vehicles WHERE id = 'v1';
-- EXPECT: 0 rows affected

-- Case: insert WITH CHECK (valid ownership)
SET LOCAL role = 'test_user_b';
INSERT INTO vehicles (id, user_id, name) VALUES ('v2', 'user_b_id', 'Car B');
-- EXPECT: success

-- Case: insert WITH CHECK (invalid ownership)
SET LOCAL role = 'test_user_b';
INSERT INTO vehicles (id, user_id, name) VALUES ('v3', 'user_a_id', 'Stolen Car');
-- EXPECT: rejected by WITH CHECK policy

-- Cleanup
RESET role;
DELETE FROM vehicles WHERE id IN ('v1', 'v2', 'v3');
