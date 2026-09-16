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

# DNS filtering. Blocky fronts Unbound on the tunnel address: it sinkholes ad and
# tracker domains and hands everything else to Unbound, which still does the
# recursion. Pinned rather than tracking latest, so every node in the fleet runs
# the same resolver — override it to upgrade one node ahead of the others.
BLOCKY_VERSION="${BLOCKY_VERSION:-v0.35.0}"
UNBOUND_PORT="5335"    # Unbound moves off :53 to make room for Blocky

# Second resolver address, for users who switch ad blocking off: Unbound reached
# directly, no blocklist, still on this node. Defaults to .254 of the tunnel /24,
# which IpAllocatorService reserves. Store it as the node's `dnsUnfiltered` column.
TUNNEL_UNFILTERED_IP="${TUNNEL_UNFILTERED_IP:-${TUNNEL_SERVER_IP%.*}.254}"

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
  wireguard wireguard-tools nftables unbound dnsutils qrencode \
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

# ── Resolver chain: Blocky → Unbound ────────────────────────────────────────────
# Clients are handed exactly one resolver address — TUNNEL_SERVER_IP, stored as
# nodes.dns and pushed into every peer's [Interface] — and that address now
# belongs to Blocky. Blocky sinkholes ad and tracker domains and forwards
# everything else to Unbound on loopback, which still does the real recursion.
# Queries leave this box the same way they did before: to the root servers, never
# to a public resolver.
#
# Order matters. Unbound has to vacate TUNNEL_SERVER_IP:53 before Blocky can bind
# it, so Unbound is reconfigured and restarted first.

# Blocky's freeBind will happily bind an address that does not exist, so a wrong
# TUNNEL_SERVER_IP yields a node that looks perfectly healthy and answers nobody:
# systemctl green, every client's DNS dead. The live fleet does NOT use this
# script's 10.7.0.0/24 default — Mumbai is 10.8, Frankfurt 10.9 — so verify the
# address against the interface that is actually up, before touching any config.
if ip link show "$WG_IF" >/dev/null 2>&1; then
  if ! ip -4 addr show "$WG_IF" | grep -qw "${TUNNEL_SERVER_IP}"; then
    cat >&2 <<MISMATCH

TUNNEL_SERVER_IP=${TUNNEL_SERVER_IP} is not an address on ${WG_IF}:
$(ip -4 -brief addr show "$WG_IF")

Refusing to point the resolver at an address no peer can reach. Re-run with the
values this node actually uses, for example:

  sudo TUNNEL_NET=10.8.0.0/24 TUNNEL_SERVER_IP=10.8.0.1 bash $0

MISMATCH
    exit 1
  fi
  ok "resolver address ${TUNNEL_SERVER_IP} confirmed on ${WG_IF}"
fi

log "Unbound recursor on 127.0.0.1:${UNBOUND_PORT}"
cat > /etc/unbound/unbound.conf.d/aegis-vpn.conf <<UNBOUND
server:
    # Blocky is the only client for this one — it forwards here after filtering.
    interface: 127.0.0.1@${UNBOUND_PORT}

    # The unfiltered resolver, reachable from inside the tunnel. Users who switch ad
    # blocking off are sent here instead of to Blocky: same recursion, same box, no
    # blocklist. The alternative — handing them a public resolver — would turn "I do
    # not want filtering" into "my lookups now leave the node", which is not the deal.
    interface: ${TUNNEL_UNFILTERED_IP}@53
    # ${TUNNEL_UNFILTERED_IP} does not exist until wg0 is up, and unbound starts first.
    ip-freebind: yes

    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    # Unbound does not listen on the tunnel address any more, so this grants
    # nothing today. It is kept so that the emergency "turn blocking off" path in
    # docs/SERVER-OPS.md — point 'interface' back at ${TUNNEL_SERVER_IP} and
    # restart — is one line, instead of one line plus an outage while somebody
    # works out why every client is getting REFUSED.
    access-control: ${TUNNEL_NET} allow

    do-ip6: no
    qname-minimisation: yes
    prefetch: yes
    cache-max-ttl: 3600
    hide-identity: yes
    hide-version: yes

    # Firefox probes this name to decide whether to switch on its own
    # DNS-over-HTTPS. NXDOMAIN means "this network filters DNS", and Firefox then
    # leaves resolution to us instead of tunnelling it to Cloudflare where the
    # blocklist cannot see it. It has to be answered here rather than in Blocky:
    # Blocky's blockType is an address, and the canary only reads NXDOMAIN.
    local-zone: "use-application-dns.net." always_nxdomain
UNBOUND
# Assign the unfiltered address to the interface.
#
# ip-freebind lets unbound BIND an address that does not exist yet, which is what
# gets it through boot. It does NOT make the address reachable: a packet arriving
# for an address the kernel does not consider local is forwarded, not delivered, so
# the listener never sees it and unbound cannot even send its replies. The address
# has to actually be on wg0.
if ip -4 addr show "$WG_IF" | grep -qw "${TUNNEL_UNFILTERED_IP}"; then
  ok "${TUNNEL_UNFILTERED_IP} already on ${WG_IF}"
else
  ip addr add "${TUNNEL_UNFILTERED_IP}/32" dev "$WG_IF"
  ok "${TUNNEL_UNFILTERED_IP}/32 added to ${WG_IF}"
fi

# And persist it, or the next `wg-quick down/up` drops it and every user who
# switched ad blocking off silently loses DNS.
WG_CONF="/etc/wireguard/${WG_IF}.conf"
if [[ -f "$WG_CONF" ]] && ! grep -q "${TUNNEL_UNFILTERED_IP}/32" "$WG_CONF"; then
  cp "$WG_CONF" "${WG_CONF}.bak-resolver"
  sed -i "s|^Address = \(.*\)$|Address = \1, ${TUNNEL_UNFILTERED_IP}/32|" "$WG_CONF"
  ok "persisted in ${WG_CONF} (backup: ${WG_CONF}.bak-resolver)"
fi

systemctl enable unbound >/dev/null 2>&1 || true
systemctl restart unbound
ok "unbound recursing on 127.0.0.1:${UNBOUND_PORT}, unfiltered on ${TUNNEL_UNFILTERED_IP}:53"

# ── Blocky ──────────────────────────────────────────────────────────────────────
log "Blocky ${BLOCKY_VERSION} (DNS filtering)"

case "$(uname -m)" in
  aarch64|arm64) BLOCKY_ARCH="arm64" ;;
  x86_64|amd64)  BLOCKY_ARCH="x86_64" ;;
  *) echo "No Blocky release for this architecture: $(uname -m)" >&2; exit 1 ;;
esac

if [[ -x /usr/local/bin/blocky ]] &&
   /usr/local/bin/blocky version 2>/dev/null | grep -q "${BLOCKY_VERSION#v}"; then
  ok "blocky ${BLOCKY_VERSION} already installed"
else
  BLOCKY_TMP="$(mktemp -d)"
  BLOCKY_TGZ="blocky_${BLOCKY_VERSION}_Linux_${BLOCKY_ARCH}.tar.gz"
  BLOCKY_URL="https://github.com/0xERR0R/blocky/releases/download/${BLOCKY_VERSION}"

  curl -fsSL "${BLOCKY_URL}/${BLOCKY_TGZ}" -o "${BLOCKY_TMP}/${BLOCKY_TGZ}"
  curl -fsSL "${BLOCKY_URL}/blocky_checksums.txt" -o "${BLOCKY_TMP}/checksums.txt"

  # One checksums file covers every platform, and 'sha256sum -c' fails the whole
  # file over the twenty archives we did not download — so check only our line.
  (cd "$BLOCKY_TMP" && grep " ${BLOCKY_TGZ}\$" checksums.txt | sha256sum -c - >/dev/null)
  ok "checksum verified"

  tar -xzf "${BLOCKY_TMP}/${BLOCKY_TGZ}" -C "$BLOCKY_TMP" blocky
  install -m 755 "${BLOCKY_TMP}/blocky" /usr/local/bin/blocky
  rm -rf "$BLOCKY_TMP"
  ok "blocky installed to /usr/local/bin/blocky"
fi

id -u blocky >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -M blocky
mkdir -p /etc/blocky

cat > /etc/blocky/config.yml <<BLOCKYCONF
# Managed by ops/provision.sh — re-running the script overwrites this file.
# The part meant to be edited by hand is /etc/blocky/allowlist.txt, which is not
# overwritten. See docs/SERVER-OPS.md.

ports:
  dns:
    - ${TUNNEL_SERVER_IP}:53
  # Metrics and the REST API, loopback only and never on the tunnel address: that
  # API can flush the cache and switch blocking off without authenticating.
  http: 127.0.0.1:4000
  # wg0 does not exist yet when Blocky starts at boot, so it has to be allowed to
  # bind an address that is not there. This is what ip-freebind did for Unbound.
  freeBind: true

upstreams:
  groups:
    default:
      - tcp+udp:127.0.0.1:${UNBOUND_PORT}
  # 'strict' keeps every query on our own Unbound. The default, parallel_best,
  # only means anything with several upstreams, and we deliberately have one — a
  # fallback to a public resolver here would be a DNS leak, not a safety net.
  strategy: strict
  timeout: 5s
  init:
    # Do not refuse to start because Unbound is half a second behind us at boot.
    strategy: fast

# Resolving the blocklist URLs must not fall through to the system resolver,
# which on Ubuntu is systemd-resolved talking to whatever DHCP handed the host.
bootstrapDns:
  - tcp+udp:127.0.0.1:${UNBOUND_PORT}

blocking:
  denylists:
    ads:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
      - https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
      - https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
  allowlists:
    ads:
      - /etc/blocky/allowlist.txt
  clientGroupsBlock:
    default:
      - ads
  # 0.0.0.0 rather than NXDOMAIN: in-app ad SDKs tend to retry or hang on
  # NXDOMAIN, where a dead address fails fast and the app gets on with itself.
  blockType: zeroIp
  blockTTL: 1m
  loading:
    refreshPeriod: 24h
    # 'fast' answers queries immediately and loads the lists behind it. A slow or
    # failed list download must never be able to take DNS down for a whole node:
    # unfiltered resolution beats no resolution.
    strategy: fast
    downloads:
      timeout: 60s
      attempts: 3
      cooldown: 10s
      # Lists survive a restart and a GitHub outage, and a refresh becomes a
      # conditional request instead of pulling all three down again.
      cachePath: /var/cache/blocky/lists
    concurrency: 4

caching:
  minTime: 5m
  maxTime: 30m
  # The nodes are small. An unbounded cache is the thing that turns a resolver
  # into the process that OOMs the box.
  maxItemsCount: 50000
  prefetching: true
  cacheTimeNegative: 10m

prometheus:
  enable: true
  path: /metrics

# A privacy VPN keeps no record of what its users looked up. 'none' is already
# the default; it is written out because an omitted section and an empty one are
# easy to confuse, and one of those logs every query to the journal.
queryLog:
  type: none

log:
  level: info
  # Domains are obfuscated in the logs, so the journal cannot quietly become the
  # query log we just turned off.
  privacy: true
BLOCKYCONF

if [[ -f /etc/blocky/allowlist.txt ]]; then
  warn "allowlist.txt exists — keeping it"
else
  cat > /etc/blocky/allowlist.txt <<'ALLOWLIST'
# Domains that are never blocked, even when a denylist contains them.
# One per line; *.wildcard and /regex/ also work. Lines starting with # are notes.
#
# You will need this. Blocklists routinely break payment gateways, delivery
# tracking and OAuth login flows. When a user reports a broken site, add the
# domain here and run:  systemctl reload blocky

# ── AdMob ───────────────────────────────────────────────────────────────────────
# The rewarded ad that BUYS ad blocking has to be able to load while ad blocking is
# on, or extending a grant is impossible: the user would need the very domains they
# just paid to block. Kept to the hosts the mobile SDK actually needs.
#
# Honest cost: pagead2 and tpc also serve web ads, so exempting them lets some
# through. That is the unavoidable price of funding a blocker with ads.
googleads.g.doubleclick.net
pagead2.googlesyndication.com
tpc.googlesyndication.com
imasdk.googleapis.com
googleadservices.com
ALLOWLIST
  ok "empty allowlist created at /etc/blocky/allowlist.txt"
fi

cat > /etc/systemd/system/blocky.service <<'BLOCKYUNIT'
[Unit]
Description=Blocky DNS filtering for the Aegis tunnel
Documentation=https://0xerr0r.github.io/blocky/
After=network-online.target unbound.service
# Wants, not Requires: if Unbound dies, Blocky should stay up and keep serving
# its cache rather than take the tunnel's only resolver down with it.
Wants=network-online.target unbound.service

[Service]
ExecStart=/usr/local/bin/blocky --config /etc/blocky/config.yml
ExecReload=/usr/bin/curl -fsS -X POST http://127.0.0.1:4000/api/lists/refresh
User=blocky
Group=blocky
Restart=on-failure
RestartSec=5s

# Port 53 without being root.
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Blocky escalates to nothing, so unlike the API service it can be locked down
# properly — see the comments in ops/aegis-api.service for why that one cannot.
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
LockPersonality=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service

CacheDirectory=blocky
CacheDirectoryMode=0750

[Install]
WantedBy=multi-user.target
BLOCKYUNIT

systemctl daemon-reload
systemctl enable blocky >/dev/null 2>&1 || true
systemctl restart blocky || true

# Not fatal to the run, but it is the difference between a node that resolves and
# one that does not, so it gets said loudly rather than left in the journal.
if systemctl is-active --quiet blocky; then
  ok "blocky answering on ${TUNNEL_SERVER_IP}:53"
else
  warn "BLOCKY FAILED TO START — there is no resolver in the tunnel. Check:"
  warn "  journalctl -u blocky -n 50 --no-pager"
fi

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
  Resolver         blocky ${BLOCKY_VERSION} on ${TUNNEL_SERVER_IP}:53 -> unbound 127.0.0.1:${UNBOUND_PORT}
  Unfiltered       ${TUNNEL_UNFILTERED_IP}:53 (set as the node's dnsUnfiltered column)
  Ad blocking      $(systemctl is-active blocky)   (allowlist: /etc/blocky/allowlist.txt)

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
  2. Check the resolver chain from inside the tunnel, from a connected peer:
       dig @${TUNNEL_SERVER_IP} example.com          +short   # a real address
       dig @${TUNNEL_SERVER_IP} doubleclick.net      +short   # must be 0.0.0.0
     Blocklists load in the background, so give it ~30s after a fresh install.
  3. Then deploy the API — see docs/DEPLOY.md.

SUMMARY
