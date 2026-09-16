#!/usr/bin/env bash
#
# Aegis VPN — resolver chain only (Blocky → Unbound).
#
# For nodes that were built BY HAND and must not be run through provision.sh.
# Mumbai is one: it has no `inet aegis` nftables table and plain iptables
# forwarding rules, so provision.sh there would be a FIRST run that drops an
# nftables forward chain with `policy drop` on top of a live node. This script
# installs the resolver and nothing else — no firewall, no sudoers, no
# PostgreSQL, no WireGuard, no packages beyond unbound and the blocky binary.
#
# It is INERT until the node's `dns` column points at TUNNEL_SERVER_IP. Installing
# it changes nothing for connected users; it only makes the address answer.
#
# The Unbound and Blocky configs here are deliberately identical to the ones in
# ops/provision.sh. KEEP THE TWO IN SYNC — provision.sh is the one that runs on
# script-built nodes, this is the one for hand-built ones.
#
# Usage:
#   sudo TUNNEL_SERVER_IP=10.8.0.1 TUNNEL_NET=10.8.0.0/24 bash ops/install-resolver.sh
#
set -euo pipefail

# No defaults for these two on purpose. Blocky's freeBind will happily bind an
# address that does not exist, so a default here would let a typo produce a node
# that starts clean, reports healthy, and answers nobody.
TUNNEL_SERVER_IP="${TUNNEL_SERVER_IP:?set TUNNEL_SERVER_IP, e.g. 10.8.0.1}"
TUNNEL_NET="${TUNNEL_NET:?set TUNNEL_NET, e.g. 10.8.0.0/24}"

WG_IF="${WG_IF:-wg0}"
UNBOUND_PORT="${UNBOUND_PORT:-5335}"
BLOCKY_VERSION="${BLOCKY_VERSION:-v0.35.0}"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0" >&2; exit 1; }

# ── Pre-flight ──────────────────────────────────────────────────────────────────
log "Pre-flight"

if ! ip link show "$WG_IF" >/dev/null 2>&1; then
  echo "No interface ${WG_IF} on this host. Refusing to guess." >&2
  exit 1
fi

if ! ip -4 addr show "$WG_IF" | grep -qw "${TUNNEL_SERVER_IP}"; then
  cat >&2 <<MISMATCH

TUNNEL_SERVER_IP=${TUNNEL_SERVER_IP} is not an address on ${WG_IF}:
$(ip -4 -brief addr show "$WG_IF")

Refusing to point the resolver at an address no peer can reach.
MISMATCH
  exit 1
fi
ok "${TUNNEL_SERVER_IP} is on ${WG_IF}"

# Anything already on that address:53 would make the Blocky start fail, or worse,
# be a resolver users are currently relying on.
if ss -ulpn 2>/dev/null | grep -q "${TUNNEL_SERVER_IP}:53"; then
  warn "something already listens on ${TUNNEL_SERVER_IP}:53 —"
  ss -ulpn | grep "${TUNNEL_SERVER_IP}:53" >&2
  echo "Refusing to take over a port that is already serving. Investigate first." >&2
  exit 1
fi
ok "${TUNNEL_SERVER_IP}:53 is free"

# ── Unbound ─────────────────────────────────────────────────────────────────────
log "Unbound recursor on 127.0.0.1:${UNBOUND_PORT}"
if ! dpkg -s unbound >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq unbound dnsutils
  ok "unbound installed"
else
  ok "unbound already installed"
fi

cat > /etc/unbound/unbound.conf.d/aegis-vpn.conf <<UNBOUND
server:
    # Loopback only. Blocky owns ${TUNNEL_SERVER_IP}:53 and is the sole client
    # here, so nothing inside the tunnel reaches Unbound directly.
    interface: 127.0.0.1@${UNBOUND_PORT}

    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    # Grants nothing today — Unbound does not listen on the tunnel address. Kept
    # so the "turn blocking off" rollback in docs/SERVER-OPS.md is one line, and
    # not one line plus an outage spent working out why clients get REFUSED.
    access-control: ${TUNNEL_NET} allow

    do-ip6: no
    qname-minimisation: yes
    prefetch: yes
    cache-max-ttl: 3600
    hide-identity: yes
    hide-version: yes

    # Firefox probes this name to decide whether to switch on its own DoH.
    # NXDOMAIN means "this network filters DNS", and Firefox then leaves
    # resolution to us rather than tunnelling it past the blocklist. It must be
    # answered here: Blocky's blockType is an address, and the canary reads only
    # NXDOMAIN.
    local-zone: "use-application-dns.net." always_nxdomain
UNBOUND

systemctl enable unbound >/dev/null 2>&1 || true
systemctl restart unbound
ok "unbound recursing on 127.0.0.1:${UNBOUND_PORT}"

# ── Blocky ──────────────────────────────────────────────────────────────────────
log "Blocky ${BLOCKY_VERSION}"

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
  # file over the archives we did not download — so check only our line.
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
# Managed by ops/install-resolver.sh — re-running overwrites this file.
# The hand-edited part is /etc/blocky/allowlist.txt, which is preserved.

ports:
  dns:
    - ${TUNNEL_SERVER_IP}:53
  # Metrics and REST API, loopback only and never on the tunnel address: that API
  # can flush the cache and switch blocking off without authenticating.
  http: 127.0.0.1:4000
  # wg0 does not exist yet when Blocky starts at boot, so it has to be allowed to
  # bind an address that is not there.
  freeBind: true

upstreams:
  groups:
    default:
      - tcp+udp:127.0.0.1:${UNBOUND_PORT}
  # 'strict' keeps every query on our own Unbound. A fallback to a public
  # resolver here would be a DNS leak, not a safety net.
  strategy: strict
  timeout: 5s
  init:
    strategy: fast

# Resolving the blocklist URLs must not fall through to the system resolver.
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
  # 0.0.0.0 rather than NXDOMAIN: in-app ad SDKs retry or hang on NXDOMAIN.
  blockType: zeroIp
  blockTTL: 1m
  loading:
    refreshPeriod: 24h
    # A failed list download must degrade to unfiltered, never to no DNS.
    strategy: fast
    downloads:
      timeout: 60s
      attempts: 3
      cooldown: 10s
      cachePath: /var/cache/blocky/lists
    concurrency: 4

caching:
  minTime: 5m
  maxTime: 30m
  maxItemsCount: 50000
  prefetching: true
  cacheTimeNegative: 10m

prometheus:
  enable: true
  path: /metrics

# A privacy VPN keeps no record of what its users looked up.
queryLog:
  type: none

log:
  level: info
  privacy: true
BLOCKYCONF

if [[ -f /etc/blocky/allowlist.txt ]]; then
  warn "allowlist.txt exists — keeping it"
else
  cat > /etc/blocky/allowlist.txt <<'ALLOWLIST'
# Domains that are never blocked, even when a denylist contains them.
# One per line; *.wildcard and /regex/ also work.
#
# You will need this. Blocklists routinely break payment gateways, delivery
# tracking and OAuth login flows. Add the domain, then: systemctl reload blocky
ALLOWLIST
  ok "empty allowlist created at /etc/blocky/allowlist.txt"
fi

cat > /etc/systemd/system/blocky.service <<'BLOCKYUNIT'
[Unit]
Description=Blocky DNS filtering for the Aegis tunnel
Documentation=https://0xerr0r.github.io/blocky/
After=network-online.target unbound.service
# Wants, not Requires: if Unbound dies, Blocky stays up serving cache rather
# than taking the tunnel's only resolver down with it.
Wants=network-online.target unbound.service

[Service]
ExecStart=/usr/local/bin/blocky --config /etc/blocky/config.yml
ExecReload=/usr/bin/curl -fsS -X POST http://127.0.0.1:4000/api/lists/refresh
User=blocky
Group=blocky
Restart=on-failure
RestartSec=5s

AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

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

if systemctl is-active --quiet blocky; then
  ok "blocky answering on ${TUNNEL_SERVER_IP}:53"
else
  warn "BLOCKY FAILED TO START. journalctl -u blocky -n 50 --no-pager"
  exit 1
fi

# ── Verify ──────────────────────────────────────────────────────────────────────
log "Verifying (lists load in the background; allow ~30s on a fresh install)"
sleep 20

resolved="$(dig @"${TUNNEL_SERVER_IP}" example.com +short +timeout=5 2>/dev/null | tail -1)"
blocked="$(dig @"${TUNNEL_SERVER_IP}" doubleclick.net +short +timeout=5 2>/dev/null | tail -1)"

echo "  example.com      -> ${resolved:-<no answer>}"
echo "  doubleclick.net  -> ${blocked:-<no answer>}"

[[ -n "$resolved" ]] || { warn "recursion is NOT working"; exit 1; }
if [[ "$blocked" == "0.0.0.0" ]]; then
  ok "blocking is live"
else
  warn "not blocking yet — lists may still be downloading. Re-check in a minute."
fi

cat <<SUMMARY

$(printf '\033[1;32m')Resolver installed.$(printf '\033[0m')

  blocky ${BLOCKY_VERSION}  ${TUNNEL_SERVER_IP}:53  ->  unbound 127.0.0.1:${UNBOUND_PORT}
  allowlist: /etc/blocky/allowlist.txt   metrics: 127.0.0.1:4000/metrics

  NOTHING CHANGED FOR USERS YET. Clients only use this once the node's 'dns'
  column is ${TUNNEL_SERVER_IP}, and existing devices keep whatever DNS was
  baked into their config at issuance.

SUMMARY
