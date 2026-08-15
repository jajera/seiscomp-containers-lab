#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io docker-compose-v2 ca-certificates curl
usermod -aG docker ubuntu
systemctl enable --now docker
