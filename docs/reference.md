---
title: Reference
layout: default
nav_order: 7
---

# Reference
{: .no_toc }

Repo layout and the four-station LEARN bindings.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Tree

| Path | Role |
|---|---|
| `compose.yaml` | Stack; must stay at repo root |
| `docker/Dockerfile` | `seiscomp-base:7.3.1` via gsm |
| `docker/Dockerfile.gui` | XFCE + xrdp sidecar |
| `docker/entrypoint.sh` | wait for MariaDB, load schema, exec module |
| `docker/import-inventory.sh` | GEOFON FDSN XML, then `update-config inventory` |
| `docker/run-seedlink.sh` / `run-slarchive.sh` | not `seiscomp exec` for those daemons |
| `config/compose/` | hostnames `mariadb`, `scmaster`, `seedlink` |
| `config/key/` | station bindings |
| `scripts/lab-up.sh` | VPC, instance, Elastic IP, then sync |
| `scripts/lab-sync.sh` | copy tree, compose build/up |
| `scripts/lab-prove.sh` | SSM checks |
| `scripts/lab-destroy.sh` | terminate instance; `--all` drops VPC/IAM |
| `docs/` | this site; `docs/docker-compose.yml` is preview only |

## Bindings

Under `config/key/` (copied to `$SEISCOMP_ROOT/etc/key`):

| Profile / key | Meaning |
|---|---|
| `global/profile_BH` | `detecStream=BH` |
| `scautopick/profile_default` | default picker (file may be empty) |
| `seedlink/profile_geofon` | chain to `geofon.gfz.de:18000`, selectors `BH?.D` |
| `slarchive/profile_week` | keep 7 days |
| `station_GE_{WLF,STU,MORC,RGN}` | `global:BH scautopick:default seedlink:geofon slarchive:week` |

Inventory URL:

```text
http://geofon.gfz.de/fdsnws/station/1/query?net=GE&sta=WLF,STU,MORC,RGN&cha=BH%3F&level=response
```

Create inventory **before** relying on `update-config` for those keys. `GE.BFO` is not in this FDSN response.

## Lab passwords

MariaDB `sysop` / `sysop` is lab-only, compose network only. RDP password is a SecureString at `/seiscomp-containers/sysop-rdp-password`. Do not commit `.env`.
