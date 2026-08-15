---
title: Walkthrough
layout: default
nav_order: 3
---

# Walkthrough
{: .no_toc }

From a laptop with AWS CLI profile `sandbox`. Region `ap-southeast-2`.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Prerequisites

- AWS CLI + Session Manager plugin
- Docker is **not** required on the laptop; images build on the instance
- Outbound HTTPS from the instance (gsm, apt, GEOFON)

```bash
export AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2 AWS_PAGER=""
```

## Create or reuse the host

```bash
./scripts/lab-up.sh
```

That script:

1. Reuses VPC/IAM tagged `Project=seiscomp-containers-lab`, or creates them
2. Opens TCP 3389 from your current public `/32`
3. Launches Ubuntu 24.04 `t3.xlarge` with `docker/ec2-user-data.sh` (Docker Engine)
4. Associates an Elastic IP
5. Waits for SSM and Docker, then runs `lab-sync.sh`

First image build runs gsm inside Docker and takes a while. Compose Bake is disabled in `lab-sync.sh` because building `scmaster` and `gui` in one Bake invoke can fail with `image already exists`.

## Update files on a running instance

```bash
./scripts/lab-sync.sh
```

Packs `compose.yaml`, `docker/`, `config/`, and related paths, copies them to `/home/ubuntu/seiscomp-containers-lab`, writes `.env` (`SYSOP_PASSWORD` from SSM), then `docker compose build` and `up`.

SSM starts as `ssm-user`. The ubuntu home directory is not world-enterable:

```bash
aws ssm start-session --target "$IID"
sudo -iu ubuntu
cd /home/ubuntu/seiscomp-containers-lab
```

## Prove

```bash
./scripts/lab-prove.sh
```

Or follow [Prove]({{ site.baseurl }}/prove/) by hand. Then [Desktop]({{ site.baseurl }}/desktop/) over RDP.

## Destroy

```bash
./scripts/lab-destroy.sh        # instance + Elastic IP; keeps VPC/IAM
./scripts/lab-destroy.sh --all  # also VPC, security group, IAM role
```

{: .cost }
> Stop instead of terminate if you will come back the same day. A stopped instance with an associated Elastic IP still has EIP charges; `lab-destroy.sh` releases the tagged address.
