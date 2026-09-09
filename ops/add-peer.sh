#!/usr/bin/env bash
#
# Aegis VPN — add a peer by hand.
#
# For proving the tunnel works BEFORE the API is involved. Generates a keypair,
# assigns the next free tunnel IP, adds the peer, and prints a client config plus a
# QR code for the official WireGuard app.
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ WARNING: peers added here are NOT in PostgreSQL.                             │
# │                                                                              │
# │ The API treats the database as the source of truth and reconciles wg0        │
# │ against it on boot, so it will DELETE any peer it does not know about.       │
# │ A peer created by this script disappears the next time the API starts.       │
# │                                                                              │
# │ Use this only before the API is deployed, or set WG_RECONCILE_ON_BOOT=false  │
# │ while you are testing by hand.                                               │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# Usage:  sudo bash ops/add-peer.sh <name>
#
set -euo pipefail

WG_IF="wg0"
TUNNEL_PREFIX="10.7.0"
WG_PORT="51820"
WG_MTU="1420"
OUT_DIR="/etc/wireguard/clients"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0 $*" >&2; exit 1; }
NAME="${1:-}"
[[ -n "$NAME" ]] || { echo "Usage: sudo bash $0 <name>" >&2; exit 1; }
[[ "$NAME" =~ ^[A-Za-z0-9_-]{1,32}$ ]] || { echo "Name must be 1-32 chars [A-Za-z0-9_-]" >&2; exit 1; }

systemctl is-active --quiet "wg-quick@${WG_IF}" || {
  echo "${WG_IF} is not up. Run ops/provision.sh first." >&2; exit 1; }

warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

warn "Peers added here are not in the database and will be removed the next time"
warn "the API starts and reconciles. See the header of this script."

# ── Next free tunnel address ────────────────────────────────────────────────────
# .1 is the server, so scan from .2 up. Addresses already on the interface are
# collected as a newline-delimited list and matched with `grep -qxF` (exact,
# whole-line, fixed-string).
#
# Deliberately not `mapfile`: that is bash 4+, and if it is unavailable the array
# ends up empty and this happily hands out .2 on top of an existing peer. A plain
# string plus grep works on any bash and cannot fail open that way.
USED_IPS="$(wg show "$WG_IF" allowed-ips | awk 'NF > 1 { print $2 }' | cut -d/ -f1 || true)"

host=""
for candidate in $(seq 2 254); do
  ip="${TUNNEL_PREFIX}.${candidate}"
  if ! printf '%s\n' "$USED_IPS" | grep -qxF "$ip"; then
    host="$candidate"
    break
  fi
done
[[ -n "$host" ]] || { echo "No free addresses in ${TUNNEL_PREFIX}.0/24" >&2; exit 1; }

CLIENT_IP="${TUNNEL_PREFIX}.${host}"

# ── Keys ────────────────────────────────────────────────────────────────────────
umask 077
mkdir -p "$OUT_DIR"
CLIENT_KEY="$(wg genkey)"
CLIENT_PUB="$(printf '%s' "$CLIENT_KEY" | wg pubkey)"
SERVER_PUB="$(cat /etc/wireguard/server.pub)"
ENDPOINT_HOST="${ENDPOINT_HOST:-$(curl -4 -s --max-time 5 ifconfig.me)}"

# ── Apply ───────────────────────────────────────────────────────────────────────
# /32 only: a wider allowed-ips would let this client source-spoof another's address.
wg set "$WG_IF" peer "$CLIENT_PUB" allowed-ips "${CLIENT_IP}/32"
wg-quick save "$WG_IF"

CONF_PATH="${OUT_DIR}/${NAME}.conf"
cat > "$CONF_PATH" <<CLIENTCONF
[Interface]
PrivateKey = ${CLIENT_KEY}
Address    = ${CLIENT_IP}/32
DNS        = ${TUNNEL_PREFIX}.1
MTU        = ${WG_MTU}

[Peer]
PublicKey           = ${SERVER_PUB}
Endpoint            = ${ENDPOINT_HOST}:${WG_PORT}
AllowedIPs          = 0.0.0.0/0, ::/0
# Mandatory on mobile: carrier NAT drops an idle tunnel after 30-60s and
# reconnects look broken without a keepalive.
PersistentKeepalive = 25
CLIENTCONF
chmod 600 "$CONF_PATH"

printf '\n\033[1;32mPeer "%s" added\033[0m  %s  ->  %s\n\n' "$NAME" "$CLIENT_PUB" "${CLIENT_IP}/32"
cat "$CONF_PATH"
printf '\nSaved to %s\n\nScan with the WireGuard app:\n\n' "$CONF_PATH"
qrencode -t ansiutf8 < "$CONF_PATH"

cat <<'NEXT'

Verify from MOBILE DATA (not Wi-Fi — most routers do not hairpin NAT):
  1. curl ifconfig.me          -> must show the server's IP
  2. dnsleaktest.com           -> only your server, not your ISP or Google
  3. test-ipv6.com             -> IPv6 unreachable, NOT your real address
  4. wg show                   -> a handshake and rising rx/tx

If pings work but large downloads hang, that is MTU. Drop to 1280 and work up.

NEXT
