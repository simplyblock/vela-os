#!/bin/sh
set -e

export PGDATA=/var/lib/postgresql/data
export WAL_MOUNT=/mnt/postgres_wal
export PGWAL=$WAL_MOUNT/wal

# Basic directories
mkdir -p "$PGDATA" /run/postgresql
chown -R postgres:postgres "$PGDATA" /run/postgresql

export INIT_OPTS="--username=vela"

# If external WAL volume is present, initialize its directory and append --waldir
if [ -d "$WAL_MOUNT" ]; then
    mkdir -p "$PGWAL"
    chown -R postgres:postgres "$WAL_MOUNT" "$PGWAL"
    INIT_OPTS="$INIT_OPTS --waldir=$PGWAL"
fi

# Initialize the Postgres database if not already initialized
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    /neonvm/bin/su-exec postgres sh -c "PGDATA=$PGDATA pg_ctl init --options=\"$INIT_OPTS\""
fi
