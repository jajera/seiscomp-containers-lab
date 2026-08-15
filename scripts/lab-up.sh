#!/usr/bin/env bash
# Create (or reuse) sandbox VPC + t3.xlarge Ubuntu, then lab-sync.sh.
# Usage: AWS_PROFILE=sandbox AWS_DEFAULT_REGION=ap-southeast-2 ./scripts/lab-up.sh
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-sandbox}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
export AWS_PAGER=""

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG_PROJECT="${TAG_PROJECT:-seiscomp-containers-lab}"
ROLE=seiscomp-containers-lab-ssm
PASS_PARAM=/seiscomp-containers-lab/sysop-rdp-password
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.xlarge}"

MYIP=$(curl -sS https://checkip.amazonaws.com | tr -d '[:space:]')
echo "operator IP ${MYIP}"

ensure_password() {
  if aws ssm get-parameter --name "$PASS_PARAM" >/dev/null 2>&1; then
    return 0
  fi
  PASS=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)
  aws ssm put-parameter --name "$PASS_PARAM" --type SecureString --value "$PASS" >/dev/null
}

ensure_iam() {
  if aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
    return 0
  fi
  aws iam create-role --role-name "$ROLE" --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]
  }' >/dev/null
  aws iam attach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  aws iam create-instance-profile --instance-profile-name "$ROLE" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$ROLE" --role-name "$ROLE"
  sleep 8
}

VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'Vpcs[0].VpcId' --output text)
if [ -z "$VPC" ] || [ "$VPC" = "None" ]; then
  VPC=$(aws ec2 create-vpc --cidr-block 10.82.0.0/16 \
    --query Vpc.VpcId --output text)
  aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-support
  aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames
  aws ec2 create-tags --resources "$VPC" --tags "Key=Project,Value=${TAG_PROJECT}" "Key=Name,Value=${TAG_PROJECT}"
  IGW=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
  aws ec2 create-tags --resources "$IGW" --tags "Key=Project,Value=${TAG_PROJECT}"
  SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.82.1.0/24 \
    --availability-zone "${AWS_DEFAULT_REGION}a" --query Subnet.SubnetId --output text)
  aws ec2 modify-subnet-attribute --subnet-id "$SUBNET" --map-public-ip-on-launch
  aws ec2 create-tags --resources "$SUBNET" --tags "Key=Project,Value=${TAG_PROJECT}"
  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" \
    --query 'RouteTables[0].RouteTableId' --output text)
  aws ec2 create-route --route-table-id "$RT" --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "$IGW" >/dev/null
  aws ec2 associate-route-table --route-table-id "$RT" --subnet-id "$SUBNET" >/dev/null || true
else
  SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
    --query 'Subnets[0].SubnetId' --output text)
fi
echo "vpc $VPC subnet $SUBNET"

SG=$(aws ec2 describe-security-groups --filters \
  "Name=vpc-id,Values=$VPC" "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'SecurityGroups[0].GroupId' --output text)
if [ -z "$SG" ] || [ "$SG" = "None" ]; then
  SG=$(aws ec2 create-security-group --vpc-id "$VPC" \
    --group-name "${TAG_PROJECT}-rdp" --description "RDP from operator" \
    --query GroupId --output text)
  aws ec2 create-tags --resources "$SG" --tags "Key=Project,Value=${TAG_PROJECT}"
fi
aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 3389 --cidr "${MYIP}/32" >/dev/null 2>&1 || true
echo "sg $SG"

ensure_iam
ensure_password

EXISTING=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
            "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "None" ]; then
  IID="${EXISTING%%[[:space:]]*}"
  echo "reusing instance $IID"
else
  AMI=$(aws ec2 describe-images --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
  echo "ami $AMI"
  IID=$(aws ec2 run-instances \
    --image-id "$AMI" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET" \
    --security-group-ids "$SG" \
    --iam-instance-profile "Name=${ROLE}" \
    --user-data "file://${ROOT}/docker/ec2-user-data.sh" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":40,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=${TAG_PROJECT}},{Key=Name,Value=${TAG_PROJECT}}]" \
    --query 'Instances[0].InstanceId' --output text)
  echo "created $IID"
  aws ec2 wait instance-running --instance-ids "$IID"
fi

ALLOC=$(aws ec2 describe-addresses --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'Addresses[0].AllocationId' --output text)
if [ -z "$ALLOC" ] || [ "$ALLOC" = "None" ]; then
  ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
  aws ec2 create-tags --resources "$ALLOC" --tags "Key=Project,Value=${TAG_PROJECT}"
fi
ASSOC_INST=$(aws ec2 describe-addresses --allocation-ids "$ALLOC" \
  --query 'Addresses[0].InstanceId' --output text)
if [ "$ASSOC_INST" != "$IID" ]; then
  aws ec2 associate-address --instance-id "$IID" --allocation-id "$ALLOC" --allow-reassociation >/dev/null
fi
EIP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC" --query 'Addresses[0].PublicIp' --output text)
echo "eip $EIP"

echo "waiting for SSM..."
for _ in $(seq 1 36); do
  st=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$IID" \
    --query 'InstanceInformationList[0].PingStatus' --output text)
  if [ "$st" = "Online" ]; then
    break
  fi
  sleep 10
done
if [ "${st:-}" != "Online" ]; then
  echo "SSM not online for $IID" >&2
  exit 1
fi

# Docker from user-data may still be installing.
python3 - "$IID" <<'PY'
import json, subprocess, sys, time
iid = sys.argv[1]
script = r"""#!/bin/bash
set -euo pipefail
for i in $(seq 1 60); do
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    docker --version
    docker compose version
    exit 0
  fi
  sleep 5
done
echo "docker not ready" >&2
exit 1
"""
cid = subprocess.check_output([
    "aws","ssm","send-command","--instance-ids",iid,
    "--document-name","AWS-RunShellScript","--comment","wait-docker",
    "--timeout-seconds","360",
    "--parameters", json.dumps({"commands":[script]}),
    "--query","Command.CommandId","--output","text"], text=True).strip()
for _ in range(80):
    data = json.loads(subprocess.check_output([
        "aws","ssm","get-command-invocation","--command-id",cid,
        "--instance-id",iid,"--output","json"], text=True))
    if data.get("Status") in ("Success","Failed","Cancelled","TimedOut"):
        print(data.get("StandardOutputContent") or "")
        print(data.get("StandardErrorContent") or "")
        sys.exit(0 if data["Status"]=="Success" else 1)
    time.sleep(5)
sys.exit(1)
PY

export IID
"$ROOT/scripts/lab-sync.sh"

echo "RDP ${EIP}:3389 user sysop (Xorg). Password: aws ssm get-parameter --name ${PASS_PARAM} --with-decryption --query Parameter.Value --output text"
echo "instance $IID"
