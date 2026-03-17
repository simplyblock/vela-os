#!/bin/sh
set -e

PGDATA=/var/lib/postgresql/data
WAL_MOUNT=/var/lib/postgresql/wal
PGWAL=$WAL_MOUNT/pg_wal

# Basic directories
mkdir -p "$PGDATA" /run/postgresql "$PGWAL"
chown -R postgres:postgres "$PGDATA" /run/postgresql "$WAL_MOUNT" "$PGWAL"
INIT_OPTS="--username=vela --waldir=$PGWAL"

# Initialize the Postgres database if not already initialized
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    /neonvm/bin/su-exec postgres sh -c "PGDATA=$PGDATA pg_ctl init --options=\"$INIT_OPTS\""
fi
