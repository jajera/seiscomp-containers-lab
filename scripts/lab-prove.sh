#!/usr/bin/env bash
# Run prove checks on the sandbox instance over SSM.
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-sandbox}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
export AWS_PAGER=""

TAG_PROJECT="${TAG_PROJECT:-seiscomp-containers}"
IID="${IID:-}"
if [ -z "$IID" ]; then
  IID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[0].InstanceId' --output text)
fi
IID="${IID%%[[:space:]]*}"
echo "prove $IID"

python3 - "$IID" <<'PY'
import json, subprocess, sys, time

iid = sys.argv[1]
script = r"""#!/bin/bash
set -euo pipefail
cd /home/ubuntu/seiscomp-containers-lab
echo '=== compose ps ==='
docker compose ps -a
echo '=== stations ==='
docker compose exec -T mariadb mariadb -usysop -psysop -N -e \
  'SELECT COUNT(*) FROM Station; SELECT COUNT(*) FROM Network;' seiscomp
echo '=== seedlink ==='
docker compose exec -T scmaster bash -lc 'slinktool -Q seedlink' | head -40
echo '=== scmaster :18180 ==='
python3 -c 'import socket; s=socket.create_connection(("127.0.0.1",18180),5); print("scmaster ok"); s.close()'
echo '=== seedlink :18000 ==='
python3 -c 'import socket; s=socket.create_connection(("127.0.0.1",18000),5); print("seedlink ok"); s.close()'
echo '=== fdsnws ==='
curl -sfS http://127.0.0.1:8080/fdsnws/station/1/version || echo 'fdsnws version failed'
curl -sfS 'http://127.0.0.1:8080/fdsnws/station/1/query?net=GE&level=station&format=text' || echo 'fdsnws station query failed'
echo '=== xrdp ==='
ss -lntp | grep 3389 || true
echo '=== launchers ==='
docker compose exec -T gui bash -lc 'ls /home/sysop/Desktop; test -x /home/sysop/bin/sc-toast-event && echo toast-script-ok'
echo '=== processor logs (tail) ==='
docker compose logs --tail=8 scautopick scqc fdsnws 2>&1 | tail -40
"""
cid = subprocess.check_output([
    "aws", "ssm", "send-command",
    "--instance-ids", iid,
    "--document-name", "AWS-RunShellScript",
    "--comment", "lab-prove",
    "--timeout-seconds", "180",
    "--parameters", json.dumps({"commands": [script]}),
    "--query", "Command.CommandId",
    "--output", "text",
], text=True).strip()
for _ in range(40):
    data = json.loads(subprocess.check_output([
        "aws", "ssm", "get-command-invocation",
        "--command-id", cid, "--instance-id", iid, "--output", "json",
    ], text=True))
    st = data.get("Status")
    if st in ("Success", "Failed", "Cancelled", "TimedOut"):
        print(data.get("StandardOutputContent") or "")
        err = data.get("StandardErrorContent") or ""
        if err:
            print("--- STDERR ---")
            print(err)
        sys.exit(0 if st == "Success" else 1)
    time.sleep(3)
print("timeout", cid, file=sys.stderr)
sys.exit(1)
PY
