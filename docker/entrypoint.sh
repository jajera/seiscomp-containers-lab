#!/bin/bash
set -euo pipefail

export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
export PATH="$SEISCOMP_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$SEISCOMP_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$SEISCOMP_ROOT/lib/python${PYTHONPATH:+:$PYTHONPATH}"

if [ "$(id -u)" = 0 ]; then
  mkdir -p "$SEISCOMP_ROOT/var/lib/seedlink" \
           "$SEISCOMP_ROOT/var/lib/archive" \
           /home/sysop/.seiscomp \
           /home/sysop/data
  chown -R sysop:sysop "$SEISCOMP_ROOT/var" /home/sysop/.seiscomp /home/sysop/data
  exec runuser -u sysop -- "$0" "$@"
fi

DB_HOST="${DB_HOST:-mariadb}"
DB_USER="${DB_USER:-sysop}"
DB_PASSWORD="${DB_PASSWORD:-sysop}"
DB_NAME="${DB_NAME:-seiscomp}"

if [ "${WAIT_FOR_DB:-1}" = "1" ]; then
  echo "waiting for ${DB_HOST}..."
  ok=0
  for _ in $(seq 1 60); do
    if mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" \
      -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 2
  done
  if [ "$ok" != "1" ]; then
    echo "database not reachable" >&2
    exit 1
  fi

  tables=$(mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -N \
    -e "SHOW TABLES" "$DB_NAME" | wc -l)
  tables=${tables//[^0-9]/}
  if [ "${tables:-0}" -lt 5 ]; then
    echo "loading $SEISCOMP_ROOT/share/db/mysql.sql"
    if ! mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
      < "$SEISCOMP_ROOT/share/db/mysql.sql"; then
      echo "schema load raced or failed; waiting for catalog..."
    fi
    for _ in $(seq 1 30); do
      tables=$(mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -N \
        -e "SHOW TABLES" "$DB_NAME" | wc -l)
      tables=${tables//[^0-9]/}
      if [ "${tables:-0}" -ge 50 ]; then
        break
      fi
      sleep 2
    done
  fi
  tables=$(mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -N \
    -e "SHOW TABLES" "$DB_NAME" | wc -l)
  tables=${tables//[^0-9]/}
  if [ "${tables:-0}" -lt 50 ]; then
    echo "database catalog incomplete (${tables:-0} tables)" >&2
    exit 1
  fi
fi

exec "$@"
