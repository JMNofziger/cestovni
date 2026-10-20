-- Least-privilege role validation
-- Scaffold. Not invoked by CI. Shipped grants are in db/migrations/0001_init.sql:
-- cestovni_app has SELECT, INSERT, UPDATE only. Soft-delete is an UPDATE.
--
-- Run after migrations are applied to verify role configuration.

-- Check 1: Runtime role cannot bypass RLS
SELECT rolname, rolbypassrls
  FROM pg_roles
 WHERE rolname = 'cestovni_app';
-- EXPECT: rolbypassrls = false

-- Check 2: Runtime role has no CREATEROLE or CREATEDB
SELECT rolname, rolcreaterole, rolcreatedb
  FROM pg_roles
 WHERE rolname = 'cestovni_app';
-- EXPECT: both false

-- Check 3: Runtime role cannot execute DDL (attempt and expect failure)
SET LOCAL role = 'cestovni_app';
-- The following should fail with "permission denied":
-- CREATE TABLE _role_test_should_fail (id int);
-- If this succeeds, the role has too many privileges.
RESET role;

-- Check 4: Migration role exists and can create tables
SELECT rolname FROM pg_roles WHERE rolname = 'cestovni_migrate';
-- EXPECT: 1 row

-- Check 5: Anonymous role has no table privileges
SELECT grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee = 'anon';
-- EXPECT: 0 rows (no grants to anon)

-- Check 6: Runtime role has only expected DML privileges
SELECT privilege_type, table_name
  FROM information_schema.role_table_grants
 WHERE grantee = 'cestovni_app'
   AND privilege_type NOT IN ('SELECT', 'INSERT', 'UPDATE');
-- EXPECT: 0 rows. DELETE is not granted. Soft-delete is an UPDATE of deleted_at.
