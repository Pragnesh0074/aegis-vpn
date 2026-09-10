#!/usr/bin/env bash
#
# Aegis VPN — AWS side of the deployment.
#
# Creates the security group, launches the instance, attaches an Elastic IP, and
# applies the two settings that cannot be applied from inside the instance:
# the source/destination check and IMDSv2 enforcement.
#
# This CREATES BILLABLE AWS RESOURCES. It prints a plan and asks for confirmation
# before creating anything.
#
# Usage:
#   ops/aws-bootstrap.sh --key-name my-keypair [--region ap-south-1] [--type t4g.small]
#
# Requires: awscli v2, configured credentials with EC2 permissions.
#
set -euo pipefail

REGION="ap-south-1"          # Mumbai: lowest tunnel latency from India
INSTANCE_TYPE="t4g.small"    # Graviton ARM64
NAME="aegis-vpn"
KEY_NAME=""
VOLUME_GB=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-name) KEY_NAME="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --type)     INSTANCE_TYPE="$2"; shift 2 ;;
    --name)     NAME="$2"; shift 2 ;;
    -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v aws >/dev/null || die "awscli not found. Install awscli v2 first."
[[ -n "$KEY_NAME" ]] || die "--key-name is required (an existing EC2 key pair)."

aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1 \
  || die "AWS credentials are not configured or lack permission. Run: aws configure"

aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1 \
  || die "Key pair '$KEY_NAME' not found in $REGION."

# Latest Ubuntu 24.04 arm64 AMI, resolved from Canonical's SSM parameter so the id is
# never stale or region-wrong.
log "Resolving the latest Ubuntu 24.04 arm64 AMI in $REGION"
AMI_ID="$(aws ssm get-parameters --region "$REGION" \
  --names /aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id \
  --query 'Parameters[0].Value' --output text)"
[[ "$AMI_ID" == ami-* ]] || die "Could not resolve an AMI id (got: $AMI_ID)"
ok "$AMI_ID"

MY_IP="$(curl -4 -s --max-time 5 ifconfig.me || true)"
[[ -n "$MY_IP" ]] || die "Could not determine your public IP (needed to scope SSH access)."

cat <<PLAN

  Plan
  ────────────────────────────────────────────────────────────
  Region          $REGION
  Instance type   $INSTANCE_TYPE   (ARM64 / Graviton)
  AMI             $AMI_ID
  Key pair        $KEY_NAME
  Root volume     ${VOLUME_GB} GB gp3
  Name tag        $NAME

  Security group "${NAME}-sg" inbound:
    udp/51820  from 0.0.0.0/0     (WireGuard)
    tcp/443    from 0.0.0.0/0     (API)
    tcp/80     from 0.0.0.0/0     (Let's Encrypt HTTP challenge)
    tcp/22     from ${MY_IP}/32   (SSH, your IP only)

  Also applied after launch:
    - source/destination check DISABLED  (required, or EC2 drops forwarded packets)
    - IMDSv2 required
    - Elastic IP allocated and associated

  These are billable resources.
PLAN

read -r -p "  Create them? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Security group ──────────────────────────────────────────────────────────────
log "Security group"
SG_ID="$(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=${NAME}-sg" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  SG_ID="$(aws ec2 create-security-group --region "$REGION" \
    --group-name "${NAME}-sg" \
    --description "Aegis VPN: WireGuard + API" \
    --query 'GroupId' --output text)"
  ok "created $SG_ID"
else
  warn "reusing existing $SG_ID"
fi

# Each rule is added independently; an already-present rule is not an error.
add_rule() {
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --protocol "$1" --port "$2" --cidr "$3" >/dev/null 2>&1 \
    && ok "$1/$2 from $3" || ok "$1/$2 from $3 (already present)"
}
add_rule udp 51820 0.0.0.0/0
add_rule tcp 443   0.0.0.0/0
add_rule tcp 80    0.0.0.0/0
add_rule tcp 22    "${MY_IP}/32"

# ── Instance ────────────────────────────────────────────────────────────────────
log "Launching instance"
INSTANCE_ID="$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=${VOLUME_GB},VolumeType=gp3,DeleteOnTermination=true}" \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME}}]" \
  --query 'Instances[0].InstanceId' --output text)"
ok "$INSTANCE_ID"

log "Waiting for the instance to reach running"
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
ok "running"

# ── The step everyone forgets ───────────────────────────────────────────────────
# With the source/destination check enabled, EC2 silently discards any packet whose
# source or destination is not the instance itself — i.e. every packet the VPN
# forwards. The tunnel handshakes and then nothing works, which is indistinguishable
# from an MTU or NAT fault.
log "Disabling the source/destination check"
aws ec2 modify-instance-attribute --region "$REGION" \
  --instance-id "$INSTANCE_ID" --no-source-dest-check
CHECK="$(aws ec2 describe-instance-attribute --region "$REGION" \
  --instance-id "$INSTANCE_ID" --attribute sourceDestCheck \
  --query 'SourceDestCheck.Value' --output text)"
[[ "$CHECK" == "False" ]] || die "source/dest check is still $CHECK — packet forwarding will not work"
ok "sourceDestCheck = False (verified)"

# ── Elastic IP ──────────────────────────────────────────────────────────────────
log "Elastic IP"
ALLOC_ID="$(aws ec2 allocate-address --region "$REGION" --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${NAME}}]" \
  --query 'AllocationId' --output text)"
aws ec2 associate-address --region "$REGION" \
  --instance-id "$INSTANCE_ID" --allocation-id "$ALLOC_ID" >/dev/null
PUBLIC_IP="$(aws ec2 describe-addresses --region "$REGION" \
  --allocation-ids "$ALLOC_ID" --query 'Addresses[0].PublicIp' --output text)"
ok "$PUBLIC_IP"

cat <<NEXT

$(printf '\033[1;32m')AWS setup complete.$(printf '\033[0m')

  Instance   $INSTANCE_ID   ($INSTANCE_TYPE, $REGION)
  Public IP  $PUBLIC_IP
  Security   ${NAME}-sg ($SG_ID)

Next:
  1. Point DNS at it and wait for it to resolve:
       A   vpn.yourdomain.com   ->   $PUBLIC_IP

  2. Provision the node:
       ssh ubuntu@$PUBLIC_IP
       sudo apt update && sudo apt -y upgrade
       git clone <your-repo> /opt/aegis-vpn
       sudo bash /opt/aegis-vpn/ops/provision.sh

  3. Follow docs/DEPLOY.md from step 5 (prove the tunnel before deploying the API).

To tear all of this down:
  aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID
  aws ec2 release-address     --region $REGION --allocation-id $ALLOC_ID
  aws ec2 delete-security-group --region $REGION --group-id $SG_ID

NEXT
