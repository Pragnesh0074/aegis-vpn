# Aegis VPN — Start & Manage Guide

## Server Details

| Item | Value |
|---|---|
| **Server IP** | `13.201.194.65` |
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
ssh -i "free-vpn-key.pem" ubuntu@13.201.194.65
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

## Deploy Code Updates

From your Mac:

```bash
cd /Users/hyperlink/StudioProjects/aegis-vpn

# Upload changed files
rsync -avz --exclude 'node_modules' --exclude '.env' --exclude 'dist' --exclude '.git' \
  -e "ssh -i free-vpn-key.pem" \
  /Users/hyperlink/StudioProjects/aegis-vpn/ \
  ubuntu@13.201.194.65:/home/ubuntu/aegis-vpn-update/
```

Then SSH in and deploy:

```bash
ssh -i "free-vpn-key.pem" ubuntu@13.201.194.65

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
```

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
Endpoint = 13.201.194.65:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25"

# Show QR
echo "$CONFIG" | qrencode -t ansiutf8

# Or save as PNG
echo "$CONFIG" | qrencode -t PNG -o ~/vpn-qr.png -s 10
```

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
