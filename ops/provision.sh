#!/usr/bin/env bash
#
# Aegis VPN — node provisioning.
#
# Sets up WireGuard, nftables, Unbound, PostgreSQL and the service account on a
# fresh Ubuntu 24.04 box. Cloud-agnostic: tested against Oracle Cloud (Ampere ARM64)
# and AWS EC2 (Graviton ARM64), and works on any Ubuntu host including bare metal.
#
# Provider-specific steps that CANNOT be done from inside the instance are detected
# and printed as reminders at the end — see check_cloud_prerequisites().
#
# Idempotent: safe to re-run. It will NOT overwrite an existing wg0.conf or server
# keypair, because doing so would invalidate every issued peer.
#
# Usage:
#   Control node (API + database on this box, the original layout):
#     sudo bash ops/provision.sh
#
#   Exit node in another country (agent only, no database):
#     sudo NODE_ROLE=exit TUNNEL_NET=10.9.0.0/24 TUNNEL_SERVER_IP=10.9.0.1 \
#          TUNNEL_SERVER_IP6=fd42:9::1 bash ops/provision.sh
#
set -euo pipefail

# Overridable, because a fleet needs one subnet per node: overlapping tunnel
# networks across nodes make logs ambiguous and rule out node-to-node routing
# later. Mumbai is 10.8.0.0/24, Frankfurt 10.9.0.0/24.
TUNNEL_NET="${TUNNEL_NET:-10.7.0.0/24}"
TUNNEL_SERVER_IP="${TUNNEL_SERVER_IP:-10.7.0.1}"
TUNNEL_SERVER_IP6="${TUNNEL_SERVER_IP6:-fd42:7::1}"

# control = this box runs the API and its database (the original single-node
#           deployment).
# exit    = this box only forwards packets and runs the node-agent. It gets no
#           PostgreSQL at all: the database is elsewhere and the agent holds no
#           database credentials, so installing one would be pure attack surface.
NODE_ROLE="${NODE_ROLE:-control}"

WG_PORT="51820"
WG_MTU="1420"          # Internet path MTU is 1500 on AWS and OCI alike (GCP needs less)
WG_IF="wg0"
DB_NAME="aegis"
DB_USER="aegis"
SERVICE_USER="vpnapi"

# ── Cloud detection ─────────────────────────────────────────────────────────────
# Each provider answers on the link-local metadata address but with a different
# handshake. Best-effort only: an unknown result is fine, it just means no
# provider-specific reminders are printed.
detect_cloud() {
  local md="http://169.254.169.254"

  # AWS requires an IMDSv2 token (IMDSv1 may be disabled).
  local token
  token="$(curl -s --max-time 2 -X PUT "$md/latest/api/token" \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null || true)"
  if [[ -n "$token" ]]; then echo "aws"; return; fi
  if curl -s --max-time 2 "$md/latest/meta-data/instance-id" >/dev/null 2>&1; then
    echo "aws"; return
  fi

  if curl -s --max-time 2 -H 'Authorization: Bearer Oracle' \
      "$md/opc/v2/instance/" >/dev/null 2>&1; then
    echo "oracle"; return
  fi

  if curl -s --max-time 2 -H 'Metadata-Flavor: Google' \
      "$md/computeMetadata/v1/instance/id" >/dev/null 2>&1; then
    echo "gcp"; return
  fi

  echo "unknown"
}

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }

# ── Detect the public NIC ────────────────────────────────────────────────────────
# The interface carrying the default route. Never hardcode eth0: Oracle ARM images
# use enp0s6, AWS uses ens5, GCP uses ens4.
NIC="$(ip -4 route show default | awk '{print $5; exit}')"
[[ -n "$NIC" ]] || { echo "Could not detect the default-route interface" >&2; exit 1; }
log "Public interface: $NIC"

# ── Packages ────────────────────────────────────────────────────────────────────
log "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  wireguard wireguard-tools nftables unbound qrencode \
  iptables-persistent curl git ca-certificates
ok "packages installed"

if [[ "$NODE_ROLE" == "control" ]]; then
  apt-get install -y -qq postgresql postgresql-contrib >/dev/null
fi

# ── IP forwarding ───────────────────────────────────────────────────────────────
log "Enabling IPv4 forwarding"
cat > /etc/sysctl.d/99-aegis-vpn.conf <<'SYSCTL'
net.ipv4.ip_forward=1
SYSCTL
sysctl --system >/dev/null
ok "net.ipv4.ip_forward=1"

# ── Host firewall ───────────────────────────────────────────────────────────────
# Oracle's Ubuntu images ship iptables rules that drop everything, ending in a
# REJECT on INPUT — opening the VCN Security List alone is not enough, and this is
# the single most common cause of "my OCI WireGuard silently doesn't work".
#
# AWS images do not do this (they rely purely on Security Groups), so these rules are
# a harmless no-op there. Applied unconditionally so the script stays portable.
#
# -C checks for the rule first, so re-running does not stack duplicates.
log "Opening host iptables (no-op on AWS, required on Oracle)"
for spec in "udp 51820" "tcp 443" "tcp 80"; do
  read -r proto port <<<"$spec"
  if iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null; then
    ok "$proto/$port already allowed"
  else
    iptables -I INPUT 1 -p "$proto" --dport "$port" -j ACCEPT
    ok "$proto/$port allowed"
  fi
done
netfilter-persistent save >/dev/null
ok "iptables rules persisted"

# ── WireGuard keys ──────────────────────────────────────────────────────────────
log "WireGuard server keypair"
umask 077
mkdir -p /etc/wireguard
if [[ -f /etc/wireguard/server.key ]]; then
  warn "server.key already exists — keeping it (regenerating would break every peer)"
else
  wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
  ok "keypair generated"
fi
chmod 600 /etc/wireguard/server.key
chmod 644 /etc/wireguard/server.pub

# ── wg0.conf ────────────────────────────────────────────────────────────────────
log "Interface config"
if [[ -f "/etc/wireguard/${WG_IF}.conf" ]]; then
  warn "${WG_IF}.conf exists — leaving it alone so existing [Peer] blocks survive"
else
  cat > "/etc/wireguard/${WG_IF}.conf" <<WGCONF
# Managed by the Aegis API. Peers are added at runtime via 'wg set' and persisted
# with 'wg-quick save'. PostgreSQL is the source of truth; this file is a cache.
[Interface]
Address    = ${TUNNEL_SERVER_IP}/24, ${TUNNEL_SERVER_IP6}/64
ListenPort = ${WG_PORT}
PrivateKey = $(cat /etc/wireguard/server.key)
MTU        = ${WG_MTU}
WGCONF
  chmod 600 "/etc/wireguard/${WG_IF}.conf"
  ok "${WG_IF}.conf created"
fi

# ── nftables ────────────────────────────────────────────────────────────────────
# Written to its own file and included from nftables.conf, so re-running replaces
# the table instead of appending a duplicate.
log "nftables NAT and egress filtering"
mkdir -p /etc/nftables.d
cat > /etc/nftables.d/aegis-vpn.nft <<NFT
table inet aegis {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    iifname "${WG_IF}" oifname "${NIC}" jump egress
  }

  chain egress {
    # Cloud instance metadata. Without this a VPN user can reach 169.254.169.254
    # and read this instance's cloud credentials.
    ip daddr 169.254.0.0/16 drop

    # Private ranges: stops users pivoting from the tunnel into our own VCN,
    # the database, or each other's tunnel addresses.
    ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8 } drop

    # Outbound mail. Spam from an exit node gets the IP blocklisted within hours.
    tcp dport { 25, 465, 587 } drop

    accept
  }

  chain postrouting {
    type nat hook postrouting priority srcnat;
    iifname "${WG_IF}" oifname "${NIC}" masquerade
  }
}
NFT

if ! grep -q 'nftables.d/aegis-vpn.nft' /etc/nftables.conf; then
  echo 'include "/etc/nftables.d/aegis-vpn.nft"' >> /etc/nftables.conf
  ok "include added to /etc/nftables.conf"
fi
systemctl enable --now nftables >/dev/null 2>&1 || true
nft -f /etc/nftables.conf
ok "ruleset loaded"

# ── Unbound ─────────────────────────────────────────────────────────────────────
log "Unbound resolver on ${TUNNEL_SERVER_IP}"
cat > /etc/unbound/unbound.conf.d/aegis-vpn.conf <<UNBOUND
server:
    interface: ${TUNNEL_SERVER_IP}
    # wg0 does not exist yet when unbound starts, so it must be allowed to bind an
    # address that is not present. Without this, unbound fails on boot.
    ip-freebind: yes

    access-control: 0.0.0.0/0 refuse
    access-control: ${TUNNEL_NET} allow
    access-control: 127.0.0.0/8 allow

    do-ip6: no
    qname-minimisation: yes
    prefetch: yes
    cache-max-ttl: 3600
    hide-identity: yes
    hide-version: yes
UNBOUND
systemctl enable unbound >/dev/null 2>&1 || true
systemctl restart unbound
ok "unbound listening inside the tunnel"

# ── Service account + narrow sudo ───────────────────────────────────────────────
log "Service account: ${SERVICE_USER}"
id -u "$SERVICE_USER" >/dev/null 2>&1 || useradd -r -m -s /bin/bash "$SERVICE_USER"

# Only these three commands, and only on this interface. The API needs root to touch
# the interface but must not be able to do anything else with it.
cat > /etc/sudoers.d/aegis-vpnapi <<SUDOERS
${SERVICE_USER} ALL=(root) NOPASSWD: /usr/bin/wg set ${WG_IF} *, /usr/bin/wg show ${WG_IF}*, /usr/bin/wg-quick save ${WG_IF}
SUDOERS
chmod 440 /etc/sudoers.d/aegis-vpnapi
visudo -cf /etc/sudoers.d/aegis-vpnapi >/dev/null
ok "sudoers rule installed and validated"

# ── PostgreSQL ──────────────────────────────────────────────────────────────────
# Control node only. An exit node has no database: Supabase holds the fleet, and
# the agent that programs this interface is given no database credentials.
DB_PASS="(not installed - exit node)"
mkdir -p /etc/aegis
if [[ "$NODE_ROLE" == "control" ]]; then
  log "PostgreSQL"
  systemctl enable --now postgresql >/dev/null 2>&1 || true

  DB_PASS_FILE=/etc/aegis/db_password
  mkdir -p /etc/aegis
  if [[ -f "$DB_PASS_FILE" ]]; then
    DB_PASS="$(cat "$DB_PASS_FILE")"
    warn "reusing the existing database password"
  else
    DB_PASS="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"
    printf '%s' "$DB_PASS" > "$DB_PASS_FILE"
    chmod 600 "$DB_PASS_FILE"
  fi

  role_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'")"
  if [[ "$role_exists" == "1" ]]; then
    sudo -u postgres psql -qc "ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}'"
    ok "role ${DB_USER} exists (password synced)"
  else
    sudo -u postgres psql -qc "CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}'"
    ok "role ${DB_USER} created"
  fi

  db_exists="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")"
  if [[ "$db_exists" == "1" ]]; then
    ok "database ${DB_NAME} exists"
  else
    sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
    ok "database ${DB_NAME} created"
  fi
fi

# ── Bring up the tunnel ─────────────────────────────────────────────────────────
log "Starting ${WG_IF}"
systemctl enable "wg-quick@${WG_IF}" >/dev/null 2>&1 || true
if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
  ok "${WG_IF} already up — not restarting (that would drop live tunnels)"
else
  systemctl start "wg-quick@${WG_IF}"
  ok "${WG_IF} up"
fi

# ── Provider-specific prerequisites ─────────────────────────────────────────────
# Things that must be done through the cloud console/CLI and cannot be applied from
# inside the instance. Getting these wrong produces the same symptom in every case:
# the WireGuard handshake completes, then no traffic flows at all.
CLOUD="$(detect_cloud)"

print_cloud_reminders() {
  case "$CLOUD" in
    aws)
      cat <<'AWSNOTE'

  ┌─ AWS ────────────────────────────────────────────────────────────────────────┐
  │ 1. DISABLE THE SOURCE/DESTINATION CHECK. This is mandatory and is the AWS     │
  │    equivalent of Oracle's host firewall trap: with it enabled, EC2 silently   │
  │    drops every forwarded packet, so the tunnel handshakes and then nothing    │
  │    works. It cannot be set from inside the instance.                          │
  │                                                                              │
  │      aws ec2 modify-instance-attribute \                                     │
  │        --instance-id <this-instance-id> --no-source-dest-check               │
  │                                                                              │
  │    Console: EC2 -> Instance -> Actions -> Networking ->                       │
  │             Change source/destination check -> Stop (uncheck)                 │
  │                                                                              │
  │ 2. Security Group inbound: UDP 51820, TCP 443, TCP 80, and SSH from your IP.  │
  │                                                                              │
  │ 3. If you use a CUSTOM Network ACL, remember NACLs are STATELESS — you need   │
  │    an outbound rule for ephemeral ports (1024-65535) as well as the inbound   │
  │    rules. The default NACL allows everything, so this only bites if changed.  │
  │                                                                              │
  │ 4. Attach an Elastic IP, or the address changes on every stop/start.          │
  └──────────────────────────────────────────────────────────────────────────────┘
AWSNOTE
      ;;
    oracle)
      cat <<'OCINOTE'

  ┌─ Oracle Cloud ───────────────────────────────────────────────────────────────┐
  │ 1. VCN Security List ingress: UDP 51820, TCP 443, TCP 80, SSH from your IP.   │
  │    The host iptables half has already been applied by this script.            │
  │ 2. Convert the ephemeral public IP to a Reserved IP so it survives a reboot.  │
  └──────────────────────────────────────────────────────────────────────────────┘
OCINOTE
      ;;
    gcp)
      cat <<'GCPNOTE'

  ┌─ Google Cloud ───────────────────────────────────────────────────────────────┐
  │ 1. The instance MUST have been created with --can-ip-forward. It cannot be    │
  │    added afterwards; the instance has to be recreated.                        │
  │ 2. GCP's VPC MTU defaults to 1460, not 1500. Lower WG_MTU to 1380 in this     │
  │    script and in the seeded node row, or large transfers will hang.           │
  │ 3. VPC firewall rule allowing udp:51820 ingress.                              │
  └──────────────────────────────────────────────────────────────────────────────┘
GCPNOTE
      ;;
    *)
      cat <<'GENERICNOTE'

  ┌─ Host ───────────────────────────────────────────────────────────────────────┐
  │ No cloud metadata service detected. Make sure UDP 51820 reaches this machine  │
  │ (port-forward it if behind NAT) and that nothing upstream filters it.         │
  └──────────────────────────────────────────────────────────────────────────────┘
GENERICNOTE
      ;;
  esac
}

# ── Summary ─────────────────────────────────────────────────────────────────────
PUBLIC_IP="$(curl -4 -s --max-time 5 ifconfig.me || echo '<unknown>')"

cat <<SUMMARY

$(printf '\033[1;32m')Provisioning complete.$(printf '\033[0m')

  Detected cloud   ${CLOUD}
  Interface        ${WG_IF} on ${NIC}
  Listening        ${PUBLIC_IP}:${WG_PORT}/udp
  Tunnel subnet    ${TUNNEL_NET}   DNS ${TUNNEL_SERVER_IP}   MTU ${WG_MTU}

  Server public key (put this in SEED_NODE_PUBLIC_KEY):
    $(cat /etc/wireguard/server.pub)

  Role             ${NODE_ROLE}
  DATABASE_URL:
    $(if [[ "$NODE_ROLE" == "control" ]]; then
        echo "postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?schema=public"
      else echo "none - exit node; the API reaches this box through its agent"; fi)

$(print_cloud_reminders)

Next:
  1. Verify the tunnel with the OFFICIAL WireGuard app before deploying the API:
       sudo bash ops/add-peer.sh test-phone
     Test over MOBILE DATA, not Wi-Fi — most routers do not hairpin NAT.
  2. Then deploy the API — see docs/DEPLOY.md.

SUMMARY
