#!/bin/bash
# Import GEOFON inventory and wait until MariaDB has stations + bindings.
# Processors read inventory from the database, not etc/inventory in this container.
set -euo pipefail

export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
export PATH="$SEISCOMP_ROOT/bin:$PATH"

DB_HOST="${DB_HOST:-mariadb}"
DB_USER="${DB_USER:-sysop}"
DB_PASSWORD="${DB_PASSWORD:-sysop}"
DB_NAME="${DB_NAME:-seiscomp}"

station_count() {
  mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -N \
    -e "SELECT COUNT(*) FROM Station" "$DB_NAME" 2>/dev/null || echo 0
}

inv="$SEISCOMP_ROOT/etc/inventory/ge-lab.xml"
if [ ! -f "$inv" ]; then
  echo "importing GEOFON inventory..."
  wget -q -O /tmp/ge-lab.xml \
    "http://geofon.gfz.de/fdsnws/station/1/query?net=GE&sta=WLF,STU,MORC,RGN&cha=BH%3F&level=response"
  seiscomp exec import_inv fdsnxml /tmp/ge-lab.xml
fi

echo "syncing inventory to database via scmaster..."
seiscomp update-config inventory

ok=0
for _ in $(seq 1 60); do
  n=$(station_count)
  n=${n//[^0-9]/}
  echo "Station rows: ${n:-0}"
  if [ "${n:-0}" -ge 4 ]; then
    ok=1
    break
  fi
  sleep 2
done
if [ "$ok" != "1" ]; then
  echo "inventory did not appear in MariaDB (need 4 stations)" >&2
  exit 1
fi

echo "syncing bindings..."
seiscomp update-config
