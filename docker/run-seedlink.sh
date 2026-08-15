#!/bin/bash
set -euo pipefail
export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
export PATH="$SEISCOMP_ROOT/bin:$PATH"

/docker/import-inventory.sh
seiscomp enable seedlink >/dev/null
seiscomp update-config seedlink
ini="$SEISCOMP_ROOT/var/lib/seedlink/seedlink.ini"
if [ ! -f "$ini" ]; then
  echo "missing $ini" >&2
  exit 1
fi
echo "starting seedlink $ini"
exec "$SEISCOMP_ROOT/sbin/seedlink" -f "$ini"
