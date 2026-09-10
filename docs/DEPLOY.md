# Deploying Aegis VPN

Works on **AWS EC2** or **Oracle Cloud** (or any Ubuntu 24.04 host). The application
is identical either way — only instance creation and the network prerequisites differ.

Roughly 45 minutes, most of it waiting on `apt`.

> The database is on **Supabase**, so the PostgreSQL parts of `provision.sh` and the
> steps below are redundant. They are harmless — skip them, or leave them as a
> fallback if you ever move the database onto the box.

---

## 1. Create the instance

<details open>
<summary><b>AWS EC2</b></summary>

### Scripted (recommended)

`ops/aws-bootstrap.sh` does every AWS-side step below, including the source/dest check
that is easy to forget. It prints a plan and asks before creating anything billable.

```bash
ops/aws-bootstrap.sh --key-name my-keypair --region ap-south-1
```

Requires awscli v2 with EC2 permissions. It resolves the current Ubuntu 24.04 arm64
AMI from Canonical's SSM parameter, so the id is never stale or region-wrong, and it
verifies `sourceDestCheck` actually flipped rather than assuming the call worked.

The manual equivalent follows.

### Manual

| Setting | Value |
|---|---|
| AMI | Ubuntu 24.04 LTS, **arm64** |
| Instance type | **t4g.small** (2 vCPU / 2 GB, Graviton) — `t4g.micro` is fine for an MVP |
| Storage | 20 GB gp3 |
| Public IP | Enable, then attach an **Elastic IP** |
| Key pair | Yours |

WireGuard runs natively on ARM/Graviton at full speed, and Graviton is the cheapest
sane option.

**Security Group inbound:**

| Source | Protocol | Port |
|---|---|---|
| `0.0.0.0/0` | **UDP** | **51820** |
| `0.0.0.0/0` | TCP | 443 |
| `0.0.0.0/0` | TCP | 80 |
| `<your IP>/32` | TCP | 22 |

### ⚠️ Disable the source/destination check

**This is mandatory and is the single AWS-specific step that breaks everything.** EC2
validates that a packet's source or destination matches the instance's own address and
**silently discards forwarded traffic** otherwise. The symptom is a WireGuard handshake
that succeeds followed by no traffic at all — indistinguishable from an MTU or NAT
problem, which is why it costs people hours.

```bash
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 --no-source-dest-check
```

Console: *EC2 → Instance → Actions → Networking → Change source/destination check →
Stop*.

It cannot be set from inside the instance, so `provision.sh` can only remind you.

### If you use a custom Network ACL

NACLs are **stateless**, unlike Security Groups. A custom NACL needs an outbound rule
for ephemeral ports (`1024-65535`) as well as the inbound rules above. The default NACL
allows everything, so this only matters if you changed it.

### Enforce IMDSv2

Defence in depth alongside the nftables rule that blocks `169.254.0.0/16` from tunnel
clients:

```bash
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required --http-endpoint enabled
```

</details>

<details>
<summary><b>Oracle Cloud (Always Free)</b></summary>

**Compute → Instances → Create:**

| Setting | Value |
|---|---|
| Image | Ubuntu 24.04 |
| Shape | **VM.Standard.A1.Flex** — 2 OCPU, 12 GB |
| Public IPv4 | Assign |
| SSH key | Paste your public key |

> **"Out of host capacity"** is the normal Ampere experience, not a mistake. Try the
> other availability domains, or retry every few minutes. Do **not** switch to an AMD
> shape — the free AMD allowance is 1/8 OCPU.

Then **Networking → Reserved IPs** → convert the ephemeral IP to reserved.

**VCN → Security Lists → Default → Add Ingress Rules:**

| Source | Protocol | Port |
|---|---|---|
| `0.0.0.0/0` | **UDP** | **51820** |
| `0.0.0.0/0` | TCP | 443 |
| `0.0.0.0/0` | TCP | 80 |
| `<your IP>/32` | TCP | 22 |

> This is **half** the firewall. Oracle's Ubuntu images also carry host iptables rules
> that drop everything. `provision.sh` opens those — it is the most common reason a
> correctly-configured OCI WireGuard appears dead.

</details>

## 2. Know what egress will cost

The one number that differs by orders of magnitude between providers. Every byte your
users pull is billable egress:

| Provider | Egress price | 1,000 users @ 20 GB/mo (20 TB) |
|---|---|---|
| Oracle Always Free | 10 TB/mo free, then ~$0.0085/GB | **~$85** |
| **AWS** | **$0.09/GB** after 100 GB/mo free | **~$1,790/mo** |

Same traffic, ~20× the bill. Hyperscaler egress is priced for API responses, not for
carrying video.

This does not affect the MVP — a handful of test devices stays inside the free
allowance. It does decide the economics later. The usual answer is to keep the control
plane wherever you like and move the **exit nodes** to a flat-rate host (Hetzner
includes 20 TB at ~€4/mo); the architecture already supports that, since a node is
just a row in the `nodes` table plus a `provision.sh` run.

Also note AWS IP ranges are published and heavily blocklisted, so users will hit more
captchas and streaming blocks than on less-recognised ranges.

## 3. DNS

```
A    vpn.yourdomain.com    ->    <reserved IP>
```

Wait for it to resolve before running Caddy, or the certificate request fails.

## 4. Provision the node

```bash
ssh ubuntu@vpn.yourdomain.com
sudo apt update && sudo apt -y upgrade
git clone <your-repo> /opt/aegis-vpn
sudo bash /opt/aegis-vpn/ops/provision.sh
```

This installs WireGuard, nftables, Unbound, PostgreSQL and the `vpnapi` service
account, and prints two things you need next: the **server public key** and the
**`DATABASE_URL`**.

It is idempotent — re-running will not overwrite `wg0.conf` or the server keypair,
because that would invalidate every issued peer.

## 5. Prove the tunnel before touching the API

Do not skip this. If the tunnel is broken, you want to know now, not while debugging
TypeScript.

```bash
sudo bash /opt/aegis-vpn/ops/add-peer.sh test-phone
```

Scan the QR with the **official WireGuard app**, connect, then **from mobile data —
not Wi-Fi** (most consumer routers do not hairpin NAT, so testing from your own
network fails misleadingly):

| Check | Expected |
|---|---|
| `curl ifconfig.me` | the server's IP |
| [dnsleaktest.com](https://dnsleaktest.com) | only your server — not your ISP, not Google |
| [test-ipv6.com](https://test-ipv6.com) | IPv6 **unreachable**, not your real address |
| `wg show` (on the server) | a handshake, and rising rx/tx |

If pings work but large downloads hang, that is MTU. Drop to 1280 and work back up.

> Delete this test peer before starting the API, or just let reconciliation remove it
> — it is not in the database, so the API will drop it on boot. That is the intended
> behaviour, not a bug.

## 6. Node.js and the API

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs caddy

cd /opt/aegis-vpn/backend
sudo -u vpnapi npm ci --omit=dev
sudo -u vpnapi npx prisma generate
sudo -u vpnapi npm run build
```

`npm ci --omit=dev` still needs the Prisma CLI for `generate` and `migrate deploy`.
If it is missing, install it once with `sudo -u vpnapi npm i prisma --no-save`.

## 7. Configure

```bash
sudo install -o root -g vpnapi -m 640 /opt/aegis-vpn/ops/api.env.example /etc/aegis/api.env
sudo nano /etc/aegis/api.env
```

Fill in:

- `DATABASE_URL` — from the `provision.sh` summary
- `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` — two **different** values from
  `openssl rand -base64 48`
- `SEED_NODE_PUBLIC_KEY` — `cat /etc/wireguard/server.pub`
- `SEED_NODE_ENDPOINT` — `vpn.yourdomain.com:51820`

Mode `640 root:vpnapi` matters: this file holds the database password and both JWT
secrets, and must not be world-readable.

The app validates all of this at boot and **refuses to start** on a bad value rather
than failing later when a user tries to connect. In particular it rejects
`WG_RUNNER=fake` under `NODE_ENV=production` — that combination would have the API
confirm peer creation over HTTP while never touching `wg0`, handing every client a
config that silently cannot connect.

## 8. Migrate and seed

```bash
cd /opt/aegis-vpn/backend
sudo -u vpnapi --preserve-env=DATABASE_URL bash -c 'set -a; . /etc/aegis/api.env; set +a; npx prisma migrate deploy && npm run seed'
```

The seed validates that `SEED_NODE_PUBLIC_KEY` is a real WireGuard public key, so a
`server.key`/`server.pub` mix-up fails loudly instead of producing peers nobody can
connect to.

## 9. Start

```bash
sudo cp /opt/aegis-vpn/ops/aegis-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now aegis-api
sudo journalctl -u aegis-api -f
```

Expected on a healthy boot:

```
Aegis VPN API listening on :3000 [production]
WireGuard runner: exec (interface wg0)
Trust proxy: true
Reconciled wg0: +0 -0 =0
```

`WireGuard runner: fake` there means the env file was not read — stop and fix it.

## 10. TLS

```bash
sudo cp /opt/aegis-vpn/ops/Caddyfile /etc/caddy/Caddyfile
sudo sed -i 's/vpn.example.com/vpn.yourdomain.com/' /etc/caddy/Caddyfile
sudo systemctl reload caddy

curl https://vpn.yourdomain.com/health
```

## 11. End-to-end check

```bash
API=https://vpn.yourdomain.com

curl -s $API/health

curl -s -X POST $API/auth/register -H 'content-type: application/json' \
  -d '{"email":"you@example.com","password":"a-long-enough-password"}'
# -> { accessToken, refreshToken, expiresIn }

TOKEN=<accessToken>
curl -s $API/nodes -H "authorization: Bearer $TOKEN"
curl -s $API/users/me -H "authorization: Bearer $TOKEN"
```

Then issue a real peer. Generate a keypair the way a client would:

```bash
PRIV=$(wg genkey); PUB=$(printf '%s' "$PRIV" | wg pubkey)

curl -s -X POST $API/devices -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d "{\"publicKey\":\"$PUB\",\"name\":\"test\",\"platform\":\"android\"}"
```

Confirm it landed on the interface:

```bash
sudo wg show wg0
```

Build a client config from the response, connect, and re-run the leak checks from
step 5. Then `DELETE /devices/:id` and confirm the peer disappears from `wg show`.

Finally, restart the API and confirm reconciliation restores state:

```bash
sudo systemctl restart aegis-api
sudo journalctl -u aegis-api -n 20 | grep Reconciled
```

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| Tunnel never handshakes | **AWS:** Security Group missing UDP 51820. **Oracle:** host iptables — check `sudo iptables -L INPUT -n --line-numbers` for the UDP 51820 ACCEPT, plus the VCN Security List rule. |
| Handshake succeeds, then nothing at all | **AWS: the source/destination check is still enabled.** This is the classic one. Also check `net.ipv4.ip_forward` and the nftables NIC name. |
| Handshake works, no internet | `net.ipv4.ip_forward`, or the nftables NIC name. `ip -4 route show default` must match the `iifname`/`oifname` in `/etc/nftables.d/aegis-vpn.nft`. |
| Pings fine, large transfers hang | MTU. Try 1280. |
| DNS resolves nothing in-tunnel | `systemctl status unbound`. Missing `ip-freebind: yes` makes it fail to bind `10.7.0.1` before wg0 exists. |
| `POST /devices` returns 500 | The sudoers rule. `sudo -u vpnapi sudo /usr/bin/wg show wg0` must work without a password prompt. |
| Every user rate-limited together | `TRUST_PROXY` is not `true`, so all requests key to Caddy's IP. |
| Peers vanish after a restart | Expected for hand-added peers — they are not in the database. Reconciliation converges `wg0` onto PostgreSQL. |
| `wg-quick save` fails in the journal | Someone added `NoNewPrivileges=yes` or `ProtectSystem=strict` to the systemd unit. Both break the sudo escalation. See the comments in `ops/aegis-api.service`. |

## Backups

The only irreplaceable state is PostgreSQL and `/etc/wireguard/server.key`.
Losing the server key invalidates every issued peer.

```bash
sudo -u postgres pg_dump aegis | gzip > aegis-$(date +%F).sql.gz
sudo cp /etc/wireguard/server.key ./server.key.bak   # store this offline
```
