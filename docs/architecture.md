---
title: Architecture
layout: default
nav_order: 2
---

# Architecture
{: .no_toc }

One VPC, one public subnet, one Ubuntu host running Docker Compose. Each SeisComP process is its own container. No NAT Gateway.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Why this layout

Each SeisComP process is a Compose service in the foreground. gsm runs **once**, in `docker/Dockerfile`, producing `seiscomp-base:7.3.1`. Other services reuse that image with a different `command`.

{: .note }
> AWS tags stay `Project=seiscomp-containers` so an existing sandbox VPC is reused. The tree on the instance is `/home/ubuntu/seiscomp-containers-lab`.

## Network

| Resource | Notes |
|---|---|
| VPC | `10.82.0.0/16`, DNS hostnames on |
| Public subnet | `10.82.1.0/24`, map public IPv4 on launch |
| Security group | egress all; inbound TCP **3389** from your `/32` only |
| IAM instance profile | `seiscomp-containers-ssm` (`AmazonSSMManagedInstanceCore`) |
| Elastic IP | associated while you want a stable RDP address |

### Not opened

- Inbound SSH (`22`) — use SSM
- Inbound SeedLink (`18000`), scmaster (`18180`), FDSNWS (`8080`), MariaDB (`3306`) — published to **host loopback** only
- The `gui` service binds **3389** on `0.0.0.0` so RDP can reach xrdp

## Compose services

```text
GEOFON geofon.gfz.de:18000
        |
        v
   seedlink  (compose DNS, host 127.0.0.1:18000)
        |
        +--> slarchive  (volume sds_archive)
        |
        v
   scautopick --> scautoloc --> scamp --> scmag --> scevent
        |
        v
   scmaster  (0.0.0.0:18180 on scnet, host 127.0.0.1:18180)
        |
        +--> mariadb (not published)
        +--> fdsnws (host 127.0.0.1:8080)
        +--> scqc, scevtlog
        +--> gui / xrdp (host :3389)
```

`compose.yaml` lives at the **repo root**. That is required: image `build.context` is `.` and `dockerfile` is `docker/Dockerfile`. `docs/docker-compose.yml` is only the Jekyll preview.

On the compose network:

- `connection.server = scmaster/production`
- `database = mysql://sysop:sysop@mariadb/seiscomp`
- `recordstream = slink://seedlink:18000`
- scmaster `interface.bind = 0.0.0.0:18180`

## Images

| Image | How |
|---|---|
| `mariadb:11.4` | official, utf8mb4_bin |
| `seiscomp-base:7.3.1` | Ubuntu 24.04 + gsm `seiscomp=7.3.1` + `world-minimal` + `install-fdsnws` |
| `seiscomp-gui:7.3.1` | `FROM seiscomp-base` + `install-gui` + XFCE + xrdp |

Later per-module images (`FROM seiscomp-base`, names like `seiscomp-*-image`) are optional. Do not clash with EarthScope repos that already use `seedlink-relay` / `slinktool-image`.

## Cost
{: .cost }
> Rough on-demand Sydney: `t3.xlarge` plus a 40 GB gp3 root volume. An Elastic IP is free while associated with a **running** instance and bills if the instance is stopped and the EIP stays allocated.
