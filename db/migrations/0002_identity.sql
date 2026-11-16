-- CES-80: identity tables and the auth/purge roles.
--
-- The migration runner wraps this file in one transaction. Do not add
-- BEGIN/COMMIT here. No new extension: gen_random_uuid() is built in on
-- Postgres 13+. No RLS on these tables. No foreign keys from product
-- tables to users. auth_login_transactions has no user_id.
--
-- Roles are cluster-wide (same DO-block pattern as 0001). Tables are
-- owned by cestovni_migrate. Roles themselves stay owned by the
-- migration superuser that runs this file.

-- ---------------------------------------------------------------------------
-- Roles (ADR 007). NOLOGIN, NOINHERIT. No BYPASSRLS, no SUPERUSER.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cestovni_auth') THEN
    CREATE ROLE cestovni_auth NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cestovni_purge') THEN
    CREATE ROLE cestovni_purge NOLOGIN NOINHERIT;
  END IF;
END
$$;

COMMENT ON ROLE cestovni_auth IS
  'Identity DML only. No product-table access. No BYPASSRLS.';
COMMENT ON ROLE cestovni_purge IS
  'Account deletion. SELECT and DELETE on product tables through RLS. No INSERT or UPDATE.';

-- ---------------------------------------------------------------------------
-- Tables. Names, types, and constraints are the CES-80 contract.
-- ---------------------------------------------------------------------------

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub TEXT NOT NULL CHECK (length(google_sub) BETWEEN 1 AND 255),
  email TEXT NULL CHECK (email IS NULL OR length(email) <= 320),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT users_google_sub_key UNIQUE (google_sub)
);
-- no unique or index on email.

CREATE TABLE auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ NULL,
  revoked_reason TEXT NULL CHECK (revoked_reason IS NULL OR length(revoked_reason) <= 64),
  CHECK (revoked_reason IS NULL OR revoked_at IS NOT NULL)
);
CREATE INDEX auth_sessions_user_id_idx ON auth_sessions (user_id);

CREATE TABLE auth_refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES auth_sessions (id) ON DELETE CASCADE,
  token_hash BYTEA NOT NULL CHECK (length(token_hash) = 32),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ NULL,
  CONSTRAINT auth_refresh_tokens_token_hash_key UNIQUE (token_hash)
);
CREATE INDEX auth_refresh_tokens_session_id_idx ON auth_refresh_tokens (session_id);

CREATE TABLE auth_oauth_states (
  state_hash BYTEA PRIMARY KEY CHECK (length(state_hash) = 32),
  code_verifier TEXT NOT NULL CHECK (length(code_verifier) BETWEEN 43 AND 128),
  client TEXT NOT NULL CHECK (client IN ('android', 'portal')),
  nonce TEXT NOT NULL CHECK (length(nonce) BETWEEN 1 AND 255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX auth_oauth_states_expires_at_idx ON auth_oauth_states (expires_at);

CREATE TABLE auth_login_transactions (
  code_hash BYTEA PRIMARY KEY CHECK (length(code_hash) = 32),
  google_sub TEXT NOT NULL CHECK (length(google_sub) BETWEEN 1 AND 255),
  email TEXT NULL CHECK (email IS NULL OR length(email) <= 320),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ NULL
);
CREATE INDEX auth_login_transactions_expires_at_idx ON auth_login_transactions (expires_at);

-- ---------------------------------------------------------------------------
-- Ownership + grants. cestovni_app gets nothing here. cestovni_auth gets
-- identity DML only. cestovni_purge gets SELECT, DELETE on product tables
-- and EXECUTE on auth_user_id(). No sequence grants.
-- ---------------------------------------------------------------------------

ALTER TABLE users OWNER TO cestovni_migrate;
ALTER TABLE auth_sessions OWNER TO cestovni_migrate;
ALTER TABLE auth_refresh_tokens OWNER TO cestovni_migrate;
ALTER TABLE auth_oauth_states OWNER TO cestovni_migrate;
ALTER TABLE auth_login_transactions OWNER TO cestovni_migrate;

REVOKE ALL ON TABLE users, auth_sessions, auth_refresh_tokens, auth_oauth_states, auth_login_transactions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users, auth_sessions, auth_refresh_tokens, auth_oauth_states, auth_login_transactions TO cestovni_auth;
GRANT SELECT, DELETE ON TABLE vehicles, fill_ups, maintenance_rules, maintenance_events, settings TO cestovni_purge;
GRANT EXECUTE ON FUNCTION auth_user_id() TO cestovni_purge;

-- DOWN (documentation only; the runner never runs this):
-- Drop child tables first. Do not drop the roles.
-- DROP TABLE auth_refresh_tokens;
-- DROP TABLE auth_sessions;
-- DROP TABLE auth_oauth_states;
-- DROP TABLE auth_login_transactions;
-- DROP TABLE users;
