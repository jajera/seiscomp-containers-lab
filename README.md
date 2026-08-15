# seiscomp-containers-lab

Unofficial LEARN SeisComP lab as **one Docker Compose service per process**, images built with **gsm** (not a source compile).

This is **not** gempa-supported.

**[Documentation](https://jajera.github.io/seiscomp-containers-lab/)** — architecture, walkthrough, prove, desktop, troubleshooting.

| | |
|---|---|
| AWS CLI profile | `sandbox` |
| Region | `ap-southeast-2` |
| OS | Ubuntu 24.04 on EC2 (`t3.xlarge` for the GUI sidecar) |
| SeisComP | 7.3.1 public gsm + `world-minimal` |
| Access | SSM; RDP to XFCE in the `gui` container |

## Layout

```text
compose.yaml          SeisComP stack (repo root on purpose)
docker/               gsm base image, seedlink/slarchive, XFCE sidecar
config/               bindings and compose hostnames
scripts/lab-*.sh      create, sync, prove, destroy the sandbox EC2
docs/                 just-the-docs site
docs/docker-compose.yml   local docs preview only
```

`compose.yaml` stays at the repo root so `build.context` is this directory and `docker compose` works after `lab-sync.sh` unpacks the tree.

## Start here (sandbox)

```bash
export AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2
./scripts/lab-up.sh
./scripts/lab-prove.sh
./scripts/lab-destroy.sh     # add --all to drop VPC/IAM
```

RDP as `sysop`, session **Xorg**. Password: SSM `/seiscomp-containers-lab/sysop-rdp-password`. On the desktop: `/home/sysop/bin/sc-toast-event "test toast"`.

Preview docs: `./scripts/docs-serve.sh` then <http://127.0.0.1:4000/seiscomp-containers-lab/>.
