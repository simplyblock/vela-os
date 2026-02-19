#!/bin/sh

set -eu

PG_VERSION_FILE=/var/lib/postgresql/data/PG_VERSION
PG_CONFIG=/etc/postgresql.conf.d/timescaledb-tune.conf

if [ ! -f "${PG_VERSION_FILE}" ]; then
    echo "pg_version file not found: ${PG_VERSION_FILE}, database not initialized"
    exit 1
fi

if [ ! -f "${PG_CONFIG}" ]; then
    echo "postgresql.conf not found: ${PG_CONFIG}"
    exit 1
fi

PG_VERSION=$(cat "$PG_VERSION_FILE")

timescaledb-tune --yes \
  --conf-path "${PG_CONFIG}" \
  --pg-version "${PG_VERSION}"
psql -U vela -d postgres -c "SELECT pg_reload_conf();"
