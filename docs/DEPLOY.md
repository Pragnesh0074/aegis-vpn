# Deploying Aegis VPN

Target: **Oracle Cloud Always Free**, Ampere A1 (ARM64), Ubuntu 24.04, Mumbai.
Everything runs on one instance — API, database and tunnel.

Roughly 45 minutes, most of it waiting on `apt`.

---

## 1. Create the instance

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

Then **Networking → Reserved IPs** → convert the ephemeral IP to reserved, so it
survives a reboot.

## 2. Open the VCN Security List

**Networking → VCN → Security Lists → Default → Add Ingress Rules:**

| Source | Protocol | Port |
|---|---|---|
| `0.0.0.0/0` | **UDP** | **51820** |
| `0.0.0.0/0` | TCP | 443 |
| `0.0.0.0/0` | TCP | 80 |
| `<your IP>/32` | TCP | 22 |

TCP 80 is only needed for Let's Encrypt's HTTP challenge.

> This is **half** the firewall. Oracle's Ubuntu images also carry host iptables rules
> that drop everything. `provision.sh` opens those — it is the most common reason a
> correctly-configured OCI WireGuard appears dead.

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
| Tunnel never handshakes | Host iptables. Check `sudo iptables -L INPUT -n --line-numbers` for the UDP 51820 ACCEPT, and confirm the VCN Security List rule. |
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
