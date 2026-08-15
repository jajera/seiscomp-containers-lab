---
title: Troubleshooting
layout: default
nav_order: 6
---

# Troubleshooting
{: .no_toc }

Failures from bringing this Compose lab up.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## SSM RunShellScript is dash

`AWS-RunShellScript` is `sh` (dash on Ubuntu), not bash. `lab-sync.sh` sends a bash shebang script as the command body. Prefer `aws ssm start-session` for interactive work.

## Compose Bake: image already exists

`docker compose build` of `scmaster` and `gui` together can fail with Bake. `lab-sync.sh` sets `COMPOSE_BAKE=false` and builds `scmaster` then `gui`.

## scautopick exits, empty stations

Processors load inventory from **MariaDB**, not `etc/inventory` in their own container. `import_inv` only writes files in seedlink. Seedlink must run `seiscomp update-config inventory` and wait for four `Station` rows before it is healthy.

Bindings need `config/key/scautopick/profile_default` or `scautopick:default` is empty.

## fdsnws: No module named twisted

The base image must source `install-fdsnws.sh` (apt wrapped to `apt-get install -y`). Rebuild `seiscomp-base` after that Dockerfile change.

## scqc exits 0 immediately

Without `--console 1` the module daemonizes and Compose sees PID 1 exit. All processors pass `--console 1`. With zero streams (no inventory) scqc still finishes acquisition and exits; fix inventory first.

## Schema load: table already exists

scmaster and seedlink both used to load `mysql.sql`. The entrypoint waits until the catalog has enough tables if a parallel load raced.

## Localhost binds vs Compose DNS

Host lab used `127.0.0.1` for scmaster, MariaDB, and fdsnws. That fails across containers. Use service names and `0.0.0.0` on the compose network. Do not publish 18000 / 18180 / 3306 / 8080 on the security group.

## seedlink is stateful

Do not `seiscomp exec seedlink`. Run `$SEISCOMP_ROOT/sbin/seedlink -f var/lib/seedlink/seedlink.ini`. Named volume `seedlink_data`. slarchive is a separate service and a separate filesystem except the SDS volume.

## gsm and apt prompt

`gsm install` without `-y` waits. `install-*.sh` calls `apt` without `-y`. The Dockerfile wraps those scripts.

## seiscomp as root

`seiscomp` refuses root unless `--asroot`. Image user is `sysop`. The entrypoint re-execs as `sysop` when Compose sets `user: "0:0"` for volume permissions.

## xrdp drops after password

Globals `port=3389` is the listen port. `[Xorg]` must stay `port=-1`. Do not sed every `port=` in `xrdp.ini`.

## notify-send does nothing

Use `/home/sysop/bin/sc-toast-event` (gdbus to xfce4-notifyd). It no-ops if notifyd is not running (no RDP session).

## No outbound internet

The instance needs a public IPv4 for apt, gsm, and outbound TCP 18000 to GEOFON. There is no NAT.
