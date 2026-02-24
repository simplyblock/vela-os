#!/bin/sh
set -e
export PGDATA=/var/lib/postgresql/data

if [ -f /neonvm/runtime/env.sh ]; then
    . /neonvm/runtime/env.sh
fi

ulimit -c unlimited

PITR_ARGS=""

if [ -n "$RECOVERY_TARGET_TIME" ] && [ ! -f "$PGDATA/.recovery_done" ]; then
    echo "Configuring Point-in-Time Recovery to $RECOVERY_TARGET_TIME"
    
    PITR_ARGS="-c recovery_target_time='$RECOVERY_TARGET_TIME' -c snapshot_pitr_target_time='$RECOVERY_TARGET_TIME'"
    
    # Mark recovery as configured so we don't do it again on next reboot
    touch "$PGDATA/.recovery_done"
fi

pg_ctl start -o "-c config_file=/vela/config/postgresql.conf -c hba_file=/vela/config/pg_hba.conf $PITR_ARGS" -l /tmp/service-postgresql.fifo
