#!/bin/bash
set -euo pipefail

if [ -n "${SYSOP_PASSWORD:-}" ]; then
  echo "sysop:${SYSOP_PASSWORD}" | chpasswd
fi

mkdir -p /var/run/xrdp /run/dbus /var/log/supervisor /var/log/xrdp
dbus-uuidgen --ensure || true
rm -f /run/dbus/pid /var/run/xrdp/xrdp-sesman.pid /var/run/xrdp/xrdp.pid

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/gui.conf
