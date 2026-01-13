#!/bin/sh
set -eu

#######################################
# Used by both ami and docker builds to initialise database schema.
# Env vars:
#   POSTGRES_DB        defaults to postgres
#   POSTGRES_HOST      defaults to localhost
#   POSTGRES_PORT      defaults to 5432
#   POSTGRES_PASSWORD  defaults to ""
# Exit code:
#   0 if migration succeeds, non-zero on error.
#######################################

export PGDATABASE="${POSTGRES_DB:-postgres}"
export PGHOST="${POSTGRES_HOST:-localhost}"
export PGPORT="${POSTGRES_PORT:-5432}"
export PGPASSWORD="$(cat /vela/secrets/db/password)"

connect="$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE?sslmode=disable"

db="/vela/migrations"
# run init scripts as postgres user
for sql in "$db"/init-scripts/*.sql; do
    [ -f "$sql" ] || continue
    echo "$0: running $sql"
    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -f "$sql"
done
psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -c "ALTER USER supabase_admin WITH PASSWORD '$PGPASSWORD'"
# run migrations as super user - postgres user demoted in post-setup
for sql in "$db"/migrations/*.sql; do
    [ -f "$sql" ] || continue
    echo "$0: running $sql"
    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -f "$sql"
done

# run any post migration script to update role passwords
#postinit="/etc/postgresql.schema.sql"
#if [ -e "$postinit" ]; then
#    echo "$0: running $postinit"
#    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -f "$postinit"
#fi

# once done with everything, reset stats from init
psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -c 'SELECT extensions.pg_stat_statements_reset(); SELECT pg_stat_reset();' || true
