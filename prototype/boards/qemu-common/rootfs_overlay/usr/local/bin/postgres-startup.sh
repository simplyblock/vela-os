#!/bin/sh
set -e
export PGDATA=/var/lib/postgresql/data

ulimit -c unlimited

pg_ctl start -o "-c config_file=/vela/config/postgresql.conf -c hba_file=/vela/config/pg_hba.conf" -l /tmp/service-postgresql.fifo
