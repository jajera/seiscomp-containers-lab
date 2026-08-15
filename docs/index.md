---
title: Overview
layout: default
nav_order: 1
---

<div class="conduit-hero">
  <p class="conduit-kicker">jajera · seiscomp-containers-lab</p>
  <h1>SeisComP containers lab</h1>
  <p class="conduit-lede">
    The same LEARN SeisComP stack as the host lab, but one Docker Compose service
    per process. Images are built with public gsm, not a source compile.
    Unofficial. Not gempa-supported.
  </p>
  <div class="conduit-actions">
    <a class="conduit-btn conduit-btn--primary" href="{{ site.baseurl }}/walkthrough/">Deploy the lab</a>
    <a class="conduit-btn conduit-btn--ghost" href="{{ site.baseurl }}/architecture/">See architecture</a>
  </div>
</div>

## What you build

One EC2 in a public subnet. Docker Compose runs MariaDB, scmaster, seedlink, slarchive, the processors, fdsnws, and an XFCE + xrdp sidecar. You reach the box with SSM. RDP opens the `gui` container for `scrttv` and the other public GUIs.

The supported gempa path is still **Linux LTS + gsm** with no containers: [seiscomp-lab](https://jajera.github.io/seiscomp-lab/). Use that unless you are specifically trying Compose.

## Read in this order

<div class="nav-grid">
  <a class="nav-card" href="{{ site.baseurl }}/architecture/">
    <strong>1. Architecture</strong>
    <span>VPC, Compose services, what is published</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/walkthrough/">
    <strong>2. Deploy and destroy</strong>
    <span>lab-up, sync, prove, teardown</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/prove/">
    <strong>3. Prove</strong>
    <span>SeedLink, FDSNWS, processors</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/desktop/">
    <strong>4. Desktop</strong>
    <span>RDP, launchers, toast, scrttv</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/troubleshooting/">
    <strong>Troubleshooting</strong>
    <span>inventory, Bake, xrdp, gsm</span>
  </a>
  <a class="nav-card" href="{{ site.baseurl }}/reference/">
    <strong>Reference</strong>
    <span>File map and bindings</span>
  </a>
</div>

## Scope

| In | Out |
|---|---|
| Ubuntu 24.04, SeisComP 7.3.1 public, `world-minimal` | gempa private/commercial gsm |
| One Compose service per process | Fat all-in-one container |
| gsm inside `seiscomp-base` | Compile from source |
| Four GEOFON BH stations | Publishing SeedLink on the security group |
| XFCE + xrdp in `gui` | Amazon DCV |
| SSM for shell access | Inbound SSH |

{: .cost }
> `t3.xlarge` is for the desktop sidecar. Stop or destroy it when you are not using RDP. See [Walkthrough]({{ site.baseurl }}/walkthrough/#destroy).
