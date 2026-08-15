---
title: Prove
layout: default
nav_order: 4
---

# Prove
{: .no_toc }

Checks from the EC2 (SSM) after `lab-sync.sh`. SeedLink, scmaster, and FDSNWS are on **host loopback** only.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Shell

```bash
export AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2
aws ssm start-session --target "$IID"
sudo -iu ubuntu
cd /home/ubuntu/seiscomp-containers-lab
```

Or from the laptop: `./scripts/lab-prove.sh`.

## Compose

```bash
docker compose ps
```

Expect one container each, all running: `mariadb` (healthy), `scmaster`, `seedlink` (healthy), `slarchive`, `scautopick`, `scautoloc`, `scamp`, `scmag`, `scevent`, `fdsnws`, `scqc`, `scevtlog`, `gui`.

Processors use `--console 1` so they stay in the foreground. Do not require `seiscomp check` (that is the systemd / `seiscomp start` path).

## Catalog and inventory

```bash
docker compose exec -T mariadb mariadb -usysop -psysop -N -e \
  'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema="seiscomp"'
docker compose exec -T mariadb mariadb -usysop -psysop -N -e \
  'SELECT COUNT(*) FROM Station' seiscomp
```

Expect about 65 tables, collation `utf8mb4_bin`, and **4** stations (`MORC`, `RGN`, `STU`, `WLF`). Inventory is written to MariaDB by `seiscomp update-config inventory` in the seedlink container, not by files in other images.

## Messaging and SeedLink

```bash
python3 -c 'import socket; s=socket.create_connection(("127.0.0.1",18180),5); print("scmaster ok"); s.close()'
python3 -c 'import socket; s=socket.create_connection(("127.0.0.1",18000),5); print("seedlink ok"); s.close()'
docker compose exec -T scmaster bash -lc 'slinktool -Q seedlink'
```

Expect BHZ/BHN/BHE for `GE.MORC`, `GE.RGN`, `GE.STU`, `GE.WLF` with end times a few seconds in the past. Wait a minute after first start.

`slarchive` should be `slarchive -SDS ... seedlink:18000`. SDS files appear under the `sds_archive` volume.

## FDSNWS

```bash
curl -sS http://127.0.0.1:8080/fdsnws/station/1/version
curl -sS 'http://127.0.0.1:8080/fdsnws/station/1/query?net=GE&level=station&format=text'
```

Expect version `1.1.6` and four GE stations. Dataselect needs SDS data; wait a few minutes after first start.

## What this does not prove

Locations with four GE stations may be rare. Empty `scolv` is normal. Desktop checks are on [Desktop]({{ site.baseurl }}/desktop/).
