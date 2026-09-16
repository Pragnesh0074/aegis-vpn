# Aegis VPN — Start & Manage Guide

## Server Details

| Item | Value |
|---|---|
| **Server IP** | `3.110.119.193` (changed 2026-09-16; was `3.111.32.212`) |
| **⚠ IP is not static** | No Elastic IP — every instance stop/start changes it. See "When the IP changes". |
| **Instance** | EC2, `ap-south-1` (Mumbai) |
| **SSH Key** | `free-vpn-key.pem` |
| **Security Group** | `vpn-server-sg` |
| **API Port** | 3000 |
| **WireGuard Port** | 51820 (UDP) |
| **Database** | Supabase (Seoul) |
| **Code location** | `/opt/aegis-vpn/backend` on server |
| **Env file** | `/etc/aegis/api.env` on server |

---

## SSH into Server

```bash
cd /Users/hyperlink/StudioProjects/aegis-vpn
ssh -i "free-vpn-key.pem" ubuntu@3.110.119.193
```

---

## Start the API

```bash
sudo systemctl start aegis-api
```

Verify it's running:

```bash
sudo systemctl status aegis-api
curl -s http://localhost:3000/health
```

Expected health response:
```json
{"status":"ok","database":"up","uptimeSeconds":5}
```

---

## Stop the API

```bash
sudo systemctl stop aegis-api
```

---

## Restart the API

```bash
sudo systemctl restart aegis-api
```

---

## View Logs

```bash
# Live logs (follow mode)
sudo journalctl -u aegis-api -f

# Last 50 lines
sudo journalctl -u aegis-api -n 50 --no-pager

# Logs since last boot
sudo journalctl -u aegis-api -b --no-pager
```

---

## WireGuard (VPN Tunnel)

WireGuard starts automatically on boot. These are independent of the API.

```bash
# Check tunnel status
sudo wg show wg0

# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Check WireGuard status
sudo systemctl status wg-quick@wg0
```

---

## DNS and Ad Blocking

Peers are handed one resolver, `10.8.0.1`, and two processes sit behind it:

```
peer ──▶ blocky  10.8.0.1:53 ──▶ unbound  127.0.0.1:5335 ──▶ root servers
```

Blocky answers `0.0.0.0` for ad and tracker domains (~79k, refreshed daily) and
forwards the rest to Unbound, which does the recursion. **If Blocky is down there
is no DNS in the tunnel** — connected users see everything time out, even though
the tunnel itself is fine.

```bash
# Is the resolver up?
sudo systemctl status blocky
sudo journalctl -u blocky -n 50 --no-pager

# Test each half separately — this is the first thing to do for any DNS report
dig @10.8.0.1 example.com +short          # blocky -> unbound -> internet
dig @127.0.0.1 -p 5335 example.com +short # unbound alone; isolates which one broke

# Blocking working?
dig @10.8.0.1 doubleclick.net +short      # expect 0.0.0.0
```

### Installing the resolver on a hand-built node

`provision.sh` assumes it built the node. Mumbai it did not: that box has no
`inet aegis` nftables table and plain iptables forwarding, so running
`provision.sh` there would be a *first* run that drops an nftables forward chain
with `policy drop` on top of a live node and can cut off every connected user.

For those, `ops/install-resolver.sh` installs the chain and nothing else — no
firewall, no sudoers, no PostgreSQL, no WireGuard:

```bash
scp -i <key>.pem ops/install-resolver.sh ubuntu@<node>:/home/ubuntu/
ssh -i <key>.pem ubuntu@<node>
sudo TUNNEL_SERVER_IP=10.8.0.1 TUNNEL_NET=10.8.0.0/24 \
  bash /home/ubuntu/install-resolver.sh
```

It refuses to run if the address is not on `wg0`, or if something already serves
on that address's port 53. It is **inert** until the node's `dns` column points
at that address.

### Unblocking a domain

Blocklists break payment gateways, delivery tracking and OAuth logins regularly.
When a user reports a broken site, find the blocked lookup, then allowlist it:

```bash
sudo nano /etc/blocky/allowlist.txt   # one domain per line; *.wildcard and /regex/ work
sudo systemctl reload blocky          # re-reads lists, no dropped queries
```

`allowlist.txt` is the one file here that `provision.sh` will **not** overwrite.
`config.yml` is regenerated on every run, so put nothing in it you want to keep.

### Emergency: turn blocking off

If a bad list update breaks things widely, this restores plain resolution in
about ten seconds without uninstalling anything — Unbound moves back onto the
tunnel address and Blocky steps aside:

```bash
sudo systemctl stop blocky
sudo sed -i 's/^    interface: 127.0.0.1@5335/    interface: 10.8.0.1\n    ip-freebind: yes/' \
  /etc/unbound/unbound.conf.d/aegis-vpn.conf
sudo systemctl restart unbound
dig @10.8.0.1 doubleclick.net +short   # now a real address: blocking is off
```

Re-run `sudo bash /opt/aegis-vpn/ops/provision.sh` to put the chain back.

On an exit node substitute its own tunnel address for `10.8.0.1` — Frankfurt
is `10.9.0.1`. It is the `dns` column of that node's row, and the address the
peers on it were issued.

### Upgrading Blocky

The version is pinned in `provision.sh` so the whole fleet runs one resolver.
Bump `BLOCKY_VERSION` there, or test a single node first:

```bash
sudo BLOCKY_VERSION=v0.36.0 bash /opt/aegis-vpn/ops/provision.sh
```

### What it does not block

Ads served from the same hostname as the content — YouTube pre-rolls, Instagram
and Facebook sponsored posts, TikTok, Spotify audio. No DNS-based blocker can
touch these, including every commercial VPN that advertises ad blocking. What
does get blocked is third-party web ads and in-app ad SDKs, which is most of
what users see. Metrics are on `127.0.0.1:4000/metrics` (loopback only).

---

## Deploy Code Updates

From your Mac:

```bash
cd /Users/hyperlink/StudioProjects/aegis-vpn

# Upload changed files
rsync -avz --exclude 'node_modules' --exclude '.env' --exclude 'dist' --exclude '.git' \
  -e "ssh -i free-vpn-key.pem" \
  /Users/hyperlink/StudioProjects/aegis-vpn/ \
  ubuntu@3.110.119.193:/home/ubuntu/aegis-vpn-update/
```

Then SSH in and deploy:

```bash
ssh -i "free-vpn-key.pem" ubuntu@3.110.119.193

# Replace code
sudo systemctl stop aegis-api
sudo rm -rf /opt/aegis-vpn.bak
sudo mv /opt/aegis-vpn /opt/aegis-vpn.bak
sudo mv /home/ubuntu/aegis-vpn-update /opt/aegis-vpn
sudo chown -R vpnapi:vpnapi /opt/aegis-vpn

# Rebuild
cd /opt/aegis-vpn/backend
sudo -u vpnapi npm ci --omit=dev
sudo -u vpnapi npm i @nestjs/cli --no-save
sudo -u vpnapi npx prisma generate
sudo -u vpnapi npx nest build

# Run new migrations (if any)
sudo -u vpnapi bash -c 'set -a; . /etc/aegis/api.env; set +a; npx prisma migrate deploy'

# Start
sudo systemctl start aegis-api
sudo journalctl -u aegis-api -n 20 --no-pager
```

---

## Edit Environment Variables

```bash
sudo nano /etc/aegis/api.env
sudo systemctl restart aegis-api
```

---

## Test the API

```bash
API="http://localhost:3000"

# Health
curl -s $API/health

# Register
curl -s -X POST $API/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"user@example.com","password":"YourPassword123"}'

# Login (returns accessToken)
curl -s -X POST $API/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"user@example.com","password":"YourPassword123"}'

# Use token for authenticated endpoints
TOKEN=<paste-accessToken-here>
curl -s $API/nodes -H "authorization: Bearer $TOKEN"
curl -s $API/users/me -H "authorization: Bearer $TOKEN"
curl -s $API/devices -H "authorization: Bearer $TOKEN"

# Where the API sees this request coming from, and whether that address belongs
# to the fleet. Unauthenticated — it only ever reports the caller's own address.
# Run it from a tunnelled machine and it should name the node you exited through.
curl -s $API/whoami
```

### Checking that peers are being seen

`Device.lastSeenAt` is written by a sweep that reads each active node's peers
every `DEVICE_LAST_SEEN_POLL_SECONDS` (default 60; 0 disables it) and moves the
matching rows forward from their latest handshake. It reads through the same
runner registry that issues peers, so **`WG_NODE_ID` must be set** once more than
one node is active — without it the sweep cannot tell which interface this host
owns and logs a warning per node instead of writing anything.

```bash
# What the sweep is doing, from the API's journal
journalctl -u aegis-api -f | grep -i 'handshake sweep'

# The raw truth it reads, on the node itself
sudo wg show wg0 latest-handshakes
```

### When a node stops answering

The same sweep is the fleet's health probe: reaching a node to read its peers is
what answers "is it there?". Two consecutive failures take it out of selection —
it stops being offered to clients, `GET /nodes` reports `healthy: false`, and the
app shows that country as **Offline** rather than Full. One success puts it back.

```bash
# Nodes going in and out of selection
journalctl -u aegis-api -f | grep -iE 'unreachable|answering again'

# What clients are being offered right now
curl -s $API/nodes -H "authorization: Bearer $TOKEN"
```

Two things worth knowing before acting on it:

- **It only sees the control plane.** A node whose agent answers while its
  traffic goes nowhere — a lost NAT rule, the AWS source/destination check
  re-enabled — reads as perfectly healthy here. `GET /whoami` from a tunnelled
  client is what catches that.
- **`active` is still yours.** Health never writes to the database; it lives in
  the API process and is re-learned within a sweep of a restart. Taking a node
  out of the fleet deliberately is still `active = false`.

Clients already on a node that goes unhealthy are moved on their next connect —
but only on **Automatic**. Someone who picked that country keeps it, and sees the
connection fail, because silently moving a person out of the country they chose
is the worse outcome.

---

## Generate a New VPN Peer (QR Code)

```bash
API="http://localhost:3000"

# Login first
TOKEN=$(curl -s -X POST $API/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"test@aegisvpn.com","password":"SuperSecurePass123!"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Generate keypair + register device
PRIV=$(wg genkey); PUB=$(printf '%s' "$PRIV" | wg pubkey)
DEVICE=$(curl -s -X POST $API/devices \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d "{\"publicKey\":\"$PUB\",\"name\":\"my-device\",\"platform\":\"android\"}")

# Parse and build config
TUNNEL_IP=$(echo "$DEVICE" | python3 -c "import sys,json; print(json.load(sys.stdin)['tunnelIp'])")
SERVER_PUB=$(echo "$DEVICE" | python3 -c "import sys,json; print(json.load(sys.stdin)['peer']['publicKey'])")

CONFIG="[Interface]
PrivateKey = $PRIV
Address = $TUNNEL_IP
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = $SERVER_PUB
Endpoint = 3.110.119.193:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25"

# Show QR
echo "$CONFIG" | qrencode -t ansiutf8

# Or save as PNG
echo "$CONFIG" | qrencode -t PNG -o ~/vpn-qr.png -s 10
```

---

## When the IP changes

The instance has **no Elastic IP**, so every stop/start assigns a new public
address. It has already changed four times (`13.201.194.65` → `13.126.153.247`
→ `13.204.63.43` → `3.111.32.212` → `3.110.119.193`). Each change silently breaks four things, in
rising order of how long they take to notice:

1. **This document** and the SSH commands in it.
2. **The Flutter client's default API origin** — `_defaultBaseUrl` in
   `app/lib/core/config/app_config.dart`. The app cannot reach the API at all.
3. **The node's `endpoint` column in the database** (`nodes` table, Mumbai row
   `501b27c5-59d2-48ac-a4d1-4e2af3a8a86d`). This is what `POST /devices` hands to
   clients. Until it is updated, every *newly issued* peer config points at the
   dead address.
4. **Every peer config already issued.** Those `Endpoint =` lines were baked in
   when the device was added and are cached on each phone. They cannot be
   rewritten remotely — affected devices must be removed and re-added.

Item 4 is the reason to fix this properly rather than repeat the checklist:

```bash
# Allocate once, associate with the instance — the address then survives stop/start.
aws ec2 allocate-address --domain vpc --region ap-south-1
aws ec2 associate-address --region ap-south-1 \
  --instance-id <instance-id> --allocation-id <eipalloc-...>
```

An Elastic IP is free while it is associated with a running instance. A DNS name
pointing at the node works too, and WireGuard re-resolves it on rehandshake — but
only the Elastic IP also protects configs already on people's phones.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| API won't start | `sudo journalctl -u aegis-api -n 50 --no-pager` |
| `WireGuard runner: fake` in logs | `/etc/aegis/api.env` has `WG_RUNNER=fake` — change to `exec` |
| VPN handshakes but no traffic | Disable source/dest check in AWS Console |
| Can't SSH in | Check Security Group has your IP for SSH |
| Database timeout | Supabase pauses after 7 days inactivity — resume from dashboard |
| Port 3000 not reachable externally | Add TCP 3000 to Security Group, or set up Caddy |

---

## Important Credentials (on server)

```bash
# Server WireGuard public key
sudo cat /etc/wireguard/server.pub

# API environment (contains JWT secrets, DB URL)
sudo cat /etc/aegis/api.env
```
