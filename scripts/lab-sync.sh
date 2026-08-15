#!/usr/bin/env bash
# Copy this tree onto the sandbox instance and docker compose build && up.
# Usage: AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2 ./scripts/lab-sync.sh
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-sandbox}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
export AWS_PAGER=""

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG_PROJECT="${TAG_PROJECT:-seiscomp-containers-lab}"
PASS_PARAM="${PASS_PARAM:-/seiscomp-containers-lab/sysop-rdp-password}"

IID="${IID:-}"
if [ -z "$IID" ]; then
  IID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
              "Name=instance-state-name,Values=running,pending" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
fi
if [ -z "$IID" ] || [ "$IID" = "None" ]; then
  echo "no running instance tagged Project=${TAG_PROJECT} (or set IID=)" >&2
  exit 1
fi
IID="${IID%%[[:space:]]*}"
echo "sync -> $IID"

PASS=$(aws ssm get-parameter --name "$PASS_PARAM" --with-decryption \
  --query Parameter.Value --output text)

TAR=$(mktemp /tmp/sc-lab.XXXXXX.tgz)
trap 'rm -f "$TAR"' EXIT
tar -czf "$TAR" -C "$ROOT" \
  --exclude='.git' \
  --exclude='*.tgz' \
  compose.yaml docker config scripts README.md .gitignore .dockerignore \
  .github docs

python3 - "$IID" "$TAR" "$PASS" <<'PY'
import base64, json, subprocess, sys, time

iid, tar_path, password = sys.argv[1], sys.argv[2], sys.argv[3]
b64 = base64.b64encode(open(tar_path, "rb").read()).decode()
chunks = [b64[i:i + 8000] for i in range(0, len(b64), 8000)]
print(f"tarball b64 {len(b64)} bytes in {len(chunks)} chunks")


def ssm(script, comment, timeout=120):
    cid = subprocess.check_output([
        "aws", "ssm", "send-command",
        "--instance-ids", iid,
        "--document-name", "AWS-RunShellScript",
        "--comment", comment,
        "--timeout-seconds", str(timeout),
        "--parameters", json.dumps({"commands": [script]}),
        "--query", "Command.CommandId",
        "--output", "text",
    ], text=True).strip()
    deadline = time.time() + timeout + 30
    while time.time() < deadline:
        data = json.loads(subprocess.check_output([
            "aws", "ssm", "get-command-invocation",
            "--command-id", cid, "--instance-id", iid, "--output", "json",
        ], text=True))
        st = data.get("Status")
        if st in ("Success", "Failed", "Cancelled", "TimedOut"):
            out = data.get("StandardOutputContent") or ""
            err = data.get("StandardErrorContent") or ""
            if out:
                sys.stdout.write(out)
            if st != "Success":
                sys.stderr.write(err or st)
                raise SystemExit(1)
            return
        time.sleep(3)
    raise SystemExit(f"ssm timeout {cid}")


ssm("rm -f /tmp/sc-lab.b64 /tmp/sc-lab.tgz", "lab-sync wipe")
for i, chunk in enumerate(chunks):
    ssm(
        f"printf '%s' '{chunk}' >> /tmp/sc-lab.b64",
        f"lab-sync chunk {i + 1}/{len(chunks)}",
    )

pw = json.dumps(password)
script = f"""#!/bin/bash
set -euo pipefail
install -d -o ubuntu -g ubuntu /home/ubuntu/seiscomp-containers-lab
python3 - <<'PY2'
import base64, pathlib
raw = pathlib.Path("/tmp/sc-lab.b64").read_text().strip()
pathlib.Path("/tmp/sc-lab.tgz").write_bytes(base64.b64decode(raw))
print("decoded", pathlib.Path("/tmp/sc-lab.tgz").stat().st_size)
PY2
sudo -u ubuntu tar -xzf /tmp/sc-lab.tgz -C /home/ubuntu/seiscomp-containers-lab
printf 'SYSOP_PASSWORD=%s\\n' {pw} | sudo -u ubuntu tee /home/ubuntu/seiscomp-containers-lab/.env >/dev/null
chmod 600 /home/ubuntu/seiscomp-containers-lab/.env
cd /home/ubuntu/seiscomp-containers-lab
export COMPOSE_BAKE=false
docker compose build scmaster
docker compose build gui
docker compose up -d --remove-orphans
docker compose ps -a
"""
ssm(script, "lab-sync compose up", timeout=3600)
PY
