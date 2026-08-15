#!/usr/bin/env bash
# Terminate the sandbox EC2 (and its EIP). Keeps VPC/IAM unless --all.
# Usage: AWS_PROFILE=sandbox ./scripts/lab-destroy.sh [--all]
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-sandbox}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
export AWS_PAGER=""

TAG_PROJECT="${TAG_PROJECT:-seiscomp-containers-lab}"
ALL=0
if [ "${1:-}" = "--all" ]; then
  ALL=1
fi

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
            "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -n "$IDS" ] && [ "$IDS" != "None" ]; then
  echo "terminating $IDS"
  # shellcheck disable=SC2086
  aws ec2 terminate-instances --instance-ids $IDS >/dev/null
  # shellcheck disable=SC2086
  aws ec2 wait instance-terminated --instance-ids $IDS
fi

ALLOCS=$(aws ec2 describe-addresses \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'Addresses[].AllocationId' --output text || true)
for a in $ALLOCS; do
  [ -z "$a" ] && continue
  ASSOC=$(aws ec2 describe-addresses --allocation-ids "$a" \
    --query 'Addresses[0].AssociationId' --output text)
  if [ -n "$ASSOC" ] && [ "$ASSOC" != "None" ]; then
    aws ec2 disassociate-address --association-id "$ASSOC" || true
  fi
  echo "releasing $a"
  aws ec2 release-address --allocation-id "$a"
done

if [ "$ALL" != "1" ]; then
  echo "kept VPC/IAM (pass --all to delete)"
  exit 0
fi

SG=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'SecurityGroups[].GroupId' --output text || true)
VPC=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=${TAG_PROJECT}" \
  --query 'Vpcs[0].VpcId' --output text || true)

if [ -n "$SG" ] && [ "$SG" != "None" ]; then
  for g in $SG; do
    echo "delete sg $g"
    aws ec2 delete-security-group --group-id "$g" || true
  done
fi

if [ -n "$VPC" ] && [ "$VPC" != "None" ]; then
  SUBS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
    --query 'Subnets[].SubnetId' --output text)
  IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
  if [ -n "$IGW" ] && [ "$IGW" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW"
  fi
  for s in $SUBS; do
    [ -z "$s" ] && continue
    aws ec2 delete-subnet --subnet-id "$s"
  done
  echo "delete vpc $VPC"
  aws ec2 delete-vpc --vpc-id "$VPC"
fi

ROLE=seiscomp-containers-lab-ssm
aws iam remove-role-from-instance-profile --instance-profile-name "$ROLE" --role-name "$ROLE" || true
aws iam delete-instance-profile --instance-profile-name "$ROLE" || true
aws iam detach-role-policy --role-name "$ROLE" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore || true
aws iam delete-role --role-name "$ROLE" || true
echo "destroy --all done"
