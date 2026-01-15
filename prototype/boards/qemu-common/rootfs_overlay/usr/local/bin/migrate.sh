#!/bin/sh
set -euo pipefail

PGPASSWORD="$(cat /vela/secrets/db/password)"

# Ensure `_vela` schema exists for migrations table
psql -v ON_ERROR_STOP=1 -U vela -d postgres -c "
  CREATE SCHEMA IF NOT EXISTS _vela;
  REVOKE CREATE ON SCHEMA _vela FROM PUBLIC;
"

dbmate \
    --url "postgres://vela@localhost:5432/postgres?sslmode=disable" \
    --migrations-dir "/vela/migrations/" \
    --migrations-table "_vela.schema_migrations" \
    --no-dump-schema up

psql -v ON_ERROR_STOP=1 -U vela -d postgres -c "
  ALTER USER postgres WITH PASSWORD '$PGPASSWORD';
  ALTER USER supabase_admin WITH PASSWORD '$PGPASSWORD';
"

# once done with everything, reset stats from init
psql -v ON_ERROR_STOP=1 -U supabase_admin -d postgres -c 'SELECT extensions.pg_stat_statements_reset(); SELECT pg_stat_reset();' || true

touch /var/run/postgresql/.migration.done

