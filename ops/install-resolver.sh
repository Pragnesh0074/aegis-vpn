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

# The unfiltered resolver's address, for users who switch ad blocking off. Defaults to
# .254 of the tunnel's /24, which is outside the allocator's range and is reserved by
# IpAllocatorService anyway. Store it as the node's `dnsUnfiltered` column.
TUNNEL_UNFILTERED_IP="${TUNNEL_UNFILTERED_IP:-${TUNNEL_SERVER_IP%.*}.254}"
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

if [[ "$TUNNEL_UNFILTERED_IP" == "$TUNNEL_SERVER_IP" ]]; then
  echo "TUNNEL_UNFILTERED_IP must differ from TUNNEL_SERVER_IP (both ${TUNNEL_SERVER_IP})" >&2
  exit 1
fi

# Something already on that address:53 is either our own Blocky — this script is
# idempotent and re-running it is normal — or a resolver users are currently relying
# on, which we must not silently displace. Only the second case is a problem.
LISTENER="$(ss -ulpnH 2>/dev/null | grep "${TUNNEL_SERVER_IP}:53" || true)"
if [[ -z "$LISTENER" ]]; then
  ok "${TUNNEL_SERVER_IP}:53 is free"
elif grep -q '"blocky"' <<<"$LISTENER"; then
  ok "${TUNNEL_SERVER_IP}:53 already served by blocky — re-running over it"
else
  warn "something other than blocky listens on ${TUNNEL_SERVER_IP}:53 —"
  printf '%s\n' "$LISTENER" >&2
  echo "Refusing to take over a port that is already serving. Investigate first." >&2
  exit 1
fi

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
    # Blocky is the only client for this one — it forwards here after filtering.
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

# The node has no IPv6 egress at all — no global address on the NIC, forwarding
# off — while peers route ::/0 into the tunnel so v6 cannot leak around the VPN.
# Handing out AAAA therefore points clients at addresses that silently blackhole:
# they wait for a reply that cannot come, and the app reports a network timeout.
# Google is IPv6-heavy, so AdMob broke on this while IPv4-only traffic was fine.
#
# Dropping AAAA makes clients use IPv4, which works. Remove this only when the
# node genuinely has IPv6 egress.
filtering:
  queryTypes:
    - AAAA

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
# Nothing is exempted by default, and ad networks especially are not.
#
# A rewarded-ad experiment once needed googleads.g.doubleclick.net allowlisted so
# our own ad could load. That host is the AdMob endpoint for EVERY app, so the
# exemption silently unblocked in-app ads across the whole device. It is gone
# along with the feature; if a future one needs it back, that trade is the thing
# to weigh, not the one host.
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

# ── Blocky (unfiltered) ─────────────────────────────────────────────────────────
# A second instance on ${TUNNEL_UNFILTERED_IP} with no blocklists, for users who
# have switched ad blocking off.
#
# Unbound used to serve this address directly. It cannot any more, because the one
# thing both resolvers must now do — refuse AAAA — is something Unbound has no
# global switch for and Blocky does. Same recursion behind it either way: both
# instances forward to the same Unbound on loopback, so a user who turns filtering
# off still has their lookups answered on this node and not by a public resolver.
log "Blocky (unfiltered) on ${TUNNEL_UNFILTERED_IP}:53"

cat > /etc/blocky/config-unfiltered.yml <<UNFILTERED
# Managed by ops — re-running overwrites this file.
# No denylists on purpose: this is the resolver for users with ad blocking OFF.

ports:
  dns:
    - ${TUNNEL_UNFILTERED_IP}:53
  # Separate port from the filtering instance, loopback only.
  http: 127.0.0.1:4001
  freeBind: true

upstreams:
  groups:
    default:
      - tcp+udp:127.0.0.1:${UNBOUND_PORT}
  strategy: strict
  timeout: 5s
  init:
    strategy: fast

bootstrapDns:
  - tcp+udp:127.0.0.1:${UNBOUND_PORT}

# The whole reason this instance exists — see the note in the filtering config.
filtering:
  queryTypes:
    - AAAA

caching:
  minTime: 5m
  maxTime: 30m
  maxItemsCount: 25000
  cacheTimeNegative: 10m

prometheus:
  enable: true
  path: /metrics

queryLog:
  type: none

log:
  level: info
  privacy: true
UNFILTERED

cat > /etc/systemd/system/blocky-unfiltered.service <<'UNFILTEREDUNIT'
[Unit]
Description=Blocky (unfiltered resolver) for the Aegis tunnel
After=network-online.target unbound.service
Wants=network-online.target unbound.service

[Service]
ExecStart=/usr/local/bin/blocky --config /etc/blocky/config-unfiltered.yml
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

CacheDirectory=blocky-unfiltered
CacheDirectoryMode=0750

[Install]
WantedBy=multi-user.target
UNFILTEREDUNIT

systemctl daemon-reload
systemctl enable blocky-unfiltered >/dev/null 2>&1 || true
systemctl restart blocky-unfiltered || true

if systemctl is-active --quiet blocky-unfiltered; then
  ok "unfiltered resolver answering on ${TUNNEL_UNFILTERED_IP}:53"
else
  warn "BLOCKY-UNFILTERED FAILED TO START — users with ad blocking off have no DNS."
  warn "  journalctl -u blocky-unfiltered -n 50 --no-pager"
fi

# ── Verify ──────────────────────────────────────────────────────────────────────
log "Verifying (lists load in the background; allow ~30s on a fresh install)"
sleep 20

resolved="$(dig @"${TUNNEL_SERVER_IP}" example.com +short +timeout=5 2>/dev/null | tail -1)"
blocked="$(dig @"${TUNNEL_SERVER_IP}" doubleclick.net +short +timeout=5 2>/dev/null | tail -1)"
unfiltered="$(dig @"${TUNNEL_UNFILTERED_IP}" doubleclick.net +short +timeout=5 2>/dev/null | tail -1)"

echo "  filtered   example.com      -> ${resolved:-<no answer>}"
echo "  filtered   doubleclick.net  -> ${blocked:-<no answer>}"
echo "  unfiltered doubleclick.net  -> ${unfiltered:-<no answer>}"

[[ -n "$resolved" ]] || { warn "recursion is NOT working"; exit 1; }
if [[ "$blocked" == "0.0.0.0" ]]; then
  ok "blocking is live"
else
  warn "not blocking yet — lists may still be downloading. Re-check in a minute."
fi

# The point of the second address is that it does NOT filter. If it answers 0.0.0.0
# the two listeners are crossed, and switching ad blocking off would change nothing.
if [[ -z "$unfiltered" ]]; then
  warn "unfiltered resolver ${TUNNEL_UNFILTERED_IP} did not answer"
elif [[ "$unfiltered" == "0.0.0.0" ]]; then
  warn "unfiltered resolver is BLOCKING — check the two interface lines in unbound.conf.d"
else
  ok "unfiltered resolver is not filtering, as intended"
fi

cat <<SUMMARY

$(printf '\033[1;32m')Resolver installed.$(printf '\033[0m')

  filtered    ${TUNNEL_SERVER_IP}:53   blocky ${BLOCKY_VERSION} -> unbound 127.0.0.1:${UNBOUND_PORT}
  unfiltered  ${TUNNEL_UNFILTERED_IP}:53   unbound direct  (set this as the node's dnsUnfiltered)
  allowlist: /etc/blocky/allowlist.txt   metrics: 127.0.0.1:4000/metrics

  NOTHING CHANGED FOR USERS YET. Clients only use this once the node's 'dns'
  column is ${TUNNEL_SERVER_IP}, and existing devices keep whatever DNS was
  baked into their config at issuance.

SUMMARY
