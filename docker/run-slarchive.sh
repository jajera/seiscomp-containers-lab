#!/bin/bash
set -euo pipefail
export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
export PATH="$SEISCOMP_ROOT/bin:$PATH"

echo "waiting for seedlink:18000..."
ok=0
for _ in $(seq 1 60); do
  if python3 -c 'import socket; socket.create_connection(("seedlink",18000),2).close()' 2>/dev/null; then
    ok=1
    break
  fi
  sleep 2
done
if [ "$ok" != "1" ]; then
  echo "seedlink not reachable" >&2
  exit 1
fi

seiscomp enable slarchive >/dev/null || true
seiscomp update-config slarchive
streams="$SEISCOMP_ROOT/var/lib/slarchive/slarchive.streams"
if [ ! -f "$streams" ]; then
  echo "missing $streams" >&2
  exit 1
fi
echo "starting slarchive -> seedlink:18000"
exec slarchive -SDS "$SEISCOMP_ROOT/var/lib/archive" -Fi:1 -Fc:900 -l "$streams" seedlink:18000
