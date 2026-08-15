---
title: Desktop
layout: default
nav_order: 5
---

# Desktop
{: .no_toc }

XFCE and xrdp run in the `gui` container, not on the Ubuntu host session.
{: .fs-5 .fw-300 }

## On this page
{: .no_toc .text-delta }

- TOC
{:toc}

---

## Connect

| Item | Value |
|---|---|
| User | `sysop` |
| Session | **Xorg** |
| Password | SSM `/seiscomp-containers/sysop-rdp-password` |
| Port | TCP 3389 from your `/32` |

```bash
export AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2
aws ssm get-parameter --name /seiscomp-containers/sysop-rdp-password \
  --with-decryption --query Parameter.Value --output text
```

`lab-up.sh` prints the Elastic IP. In Remote Desktop, pick session **Xorg** and accept the certificate warning.

{: .warning }
> If your public IP changed, 3389 will time out until you add a security group rule for the new `/32`.

## On the desktop

1. Terminal: `/home/sysop/bin/sc-toast-event "test toast"` — notification titled SeisComP (top-right). Needs xfce4-notifyd in this RDP session; SSM cannot show it.
2. **scrttv** — live BH for the four GE stations.
3. **scmm** — `scmaster` plus processor clients.
4. Optional: **scmv**, **scheli**, **scqcv**.

Launchers are written at image build (`docker/gui/write-launchers.sh`) and call `/home/sysop/bin/sc-launch`.

## What stays quiet

Real earthquake toasts need picks and an event. Four GEOFON stations are often quiet. The scripted toast is the desktop proof. **scolv** stays empty until there is an event.
