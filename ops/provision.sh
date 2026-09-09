#!/usr/bin/env bash
#
# Aegis VPN — node provisioning.
#
# Sets up WireGuard, nftables, Unbound, PostgreSQL and the service account on a
# fresh Ubuntu 24.04 box. Written for Oracle Cloud Ampere (ARM64) but works on any
# Ubuntu host.
#
# Idempotent: safe to re-run. It will NOT overwrite an existing wg0.conf or server
# keypair, because doing so would invalidate every issued peer.
#
# Usage:  sudo bash ops/provision.sh
#
set -euo pipefail

TUNNEL_NET="10.7.0.0/24"
TUNNEL_SERVER_IP="10.7.0.1"
TUNNEL_SERVER_IP6="fd42:7::1"
WG_PORT="51820"
WG_MTU="1420"          # OCI's internet path MTU is 1500, so no reduction needed
WG_IF="wg0"
DB_NAME="aegis"
DB_USER="aegis"
SERVICE_USER="vpnapi"

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
  postgresql postgresql-contrib \
  iptables-persistent curl git ca-certificates
ok "packages installed"

# ── IP forwarding ───────────────────────────────────────────────────────────────
log "Enabling IPv4 forwarding"
cat > /etc/sysctl.d/99-aegis-vpn.conf <<'SYSCTL'
net.ipv4.ip_forward=1
SYSCTL
sysctl --system >/dev/null
ok "net.ipv4.ip_forward=1"

# ── Oracle's second firewall ────────────────────────────────────────────────────
# Opening the VCN Security List is NOT enough. Oracle's Ubuntu images ship iptables
# rules that drop everything, ending in a REJECT on INPUT. This is the single most
# common cause of "my OCI WireGuard silently doesn't work".
#
# -C checks for the rule first, so re-running does not stack duplicates.
log "Opening host iptables (Oracle images drop by default)"
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

# ── Bring up the tunnel ─────────────────────────────────────────────────────────
log "Starting ${WG_IF}"
systemctl enable "wg-quick@${WG_IF}" >/dev/null 2>&1 || true
if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
  ok "${WG_IF} already up — not restarting (that would drop live tunnels)"
else
  systemctl start "wg-quick@${WG_IF}"
  ok "${WG_IF} up"
fi

# ── Summary ─────────────────────────────────────────────────────────────────────
PUBLIC_IP="$(curl -4 -s --max-time 5 ifconfig.me || echo '<unknown>')"

cat <<SUMMARY

$(printf '\033[1;32m')Provisioning complete.$(printf '\033[0m')

  Interface        ${WG_IF} on ${NIC}
  Listening        ${PUBLIC_IP}:${WG_PORT}/udp
  Tunnel subnet    ${TUNNEL_NET}   DNS ${TUNNEL_SERVER_IP}   MTU ${WG_MTU}

  Server public key (put this in SEED_NODE_PUBLIC_KEY):
    $(cat /etc/wireguard/server.pub)

  DATABASE_URL:
    postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?schema=public

Next:
  1. Verify the tunnel with the OFFICIAL WireGuard app before deploying the API:
       sudo bash ops/add-peer.sh test-phone
     Test over MOBILE DATA, not Wi-Fi — most routers do not hairpin NAT.
  2. Then deploy the API — see docs/DEPLOY.md.

SUMMARY
