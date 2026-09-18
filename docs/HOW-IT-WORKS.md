# How Aegis actually works

The thing that trips people up: **the backend is not the VPN.** It is a registration
desk. The VPN is a Linux machine somewhere else, and that machine is the product.

---

## The one rule

A VPN means your traffic reaches the internet from **a different machine**, so websites
see that machine's IP instead of yours.

If there is no second machine, there is nowhere else for traffic to come out of, and
there is no VPN. This is definitional. No amount of backend code substitutes for it.

```
No server:                        With a server:

Phone ──> internet                Phone ══encrypted══> SERVER ──> internet
   (your own IP — not a VPN)                            ↑
                                              websites see THIS ip
```

---

## The three machines

| Machine | Runs | Sees your traffic? |
|---|---|---|
| **Phone** | Flutter app, WireGuard client, its own private key | yes (it is yours) |
| **VPN node** (EC2) | `wg0`, nftables, Unbound, **and the NestJS API** | yes — it is the exit point |
| **Database** (Supabase) | Postgres: users, devices, nodes | no — only account records |

Note the second row: for the MVP the API and the tunnel share one box. They are still
separate concerns, which is why splitting them later is only a config change.

---

## Setup: how a device gets a tunnel

Happens once per device, over HTTPS.

```
1. Phone generates an X25519 keypair locally.
   The PRIVATE key is written to Keychain/Keystore and never transmitted. Ever.

2. Phone ──POST /devices { publicKey }──> API

3. API:
     - checks the device cap                      (UsersService)
     - picks a node                               (NodesService)
     - allocates the lowest free tunnel IP        (IpAllocatorService)
     - writes the device row                      (Postgres)
     - runs: sudo wg set wg0 peer <pubkey> allowed-ips 10.7.0.2/32
                                                  (WireguardService -> ExecWgRunner)

4. API ──> Phone:
     { tunnelIp: "10.7.0.2/32", dns: "10.7.0.1", mtu: 1280,
       peer: { publicKey: <SERVER's public key>,
               endpoint: "vpn.example.com:51820",
               allowedIps: "0.0.0.0/0, ::/0",
               persistentKeepalive: 25 } }

5. Phone assembles a WireGuard config from that and connects.
```

Only **public** keys cross the network. The API never possesses either private key,
which is why "we cannot decrypt your traffic" is a structural fact rather than a
promise.

---

## Traffic: what happens to a packet

Every packet, forever after. **The API is not involved.**

```
  Phone wants https://example.com
       │
       │ 1. WireGuard encrypts the whole IP packet with the server's public key
       ▼
  UDP :51820 ─────── the public internet ───────> VPN node
                                                      │
                                    2. kernel WireGuard decrypts, confirms the
                                       sender is a known peer at 10.7.0.2
                                                      │
                                    3. nftables `egress` chain drops it if aimed at
                                       cloud metadata / RFC1918 / SMTP, else accepts
                                                      │
                                    4. nftables `postrouting` masquerades: source
                                       becomes the node's public IP
                                                      ▼
                                                 example.com
                                       (sees the NODE's IP, not the phone's)
```

The reply retraces the path and is encrypted back to that peer. Where a node runs
its own resolver, DNS is answered inside the tunnel and lookups never reach the
local ISP. Two processes sit behind that one address:

```
peer ──▶ blocky  10.7.0.1:53 ──▶ unbound  127.0.0.1:5335 ──▶ root servers
         sinkholes ad and        recursion, DNSSEC,
         tracker domains         cache
```

Blocky answers `0.0.0.0` for anything on its blocklists (~79k domains: ads,
trackers, telemetry) and passes everything else through. Unbound still does the
actual resolving, so the "queries never leave the node" property is unchanged.

**This is per-node, and the fleet is not uniform.** A node hands out whatever is
in its `dns` column. Frankfurt points at its own resolver (`10.9.0.1`); Mumbai
still points at `1.1.1.1`, so its users resolve through Cloudflare and get no
filtering, even though the resolver is installed and running on the box. Check
the column, not the diagram.

This kills third-party ads — the web, and in-app ad SDKs like AdMob and Unity
Ads. It cannot touch ads served from the same hostname as the content, which is
how YouTube, Instagram and TikTok deliver theirs; no DNS filter can. Say so in
the UI rather than letting users discover it.

**If the API is down, live tunnels keep working.** It is only needed to add or remove a
device.

---

## Why there are two runners

`WireguardService` never calls `wg` directly. It goes through the `WgRunner` port:

| Implementation | Used when | Behaviour |
|---|---|---|
| `ExecWgRunner` | `WG_RUNNER=exec` | Really runs `wg` via `execFile` with an argv array |
| `FakeWgRunner` | `WG_RUNNER=fake` | Keeps peers in a `Map` |

macOS has no WireGuard kernel module, so `wg` does not exist on a dev laptop. The fake
runner exists so the other 98% of the system — auth, allocation, the device lifecycle,
every HTTP concern — can be built and tested without a Linux box.

It substitutes for exactly two commands:

```
wg set wg0 peer <key> allowed-ips 10.7.0.2/32
wg show wg0 dump
```

`env.validation.ts` **refuses to boot** with `WG_RUNNER=fake` under
`NODE_ENV=production`, because the API would otherwise confirm peer creation over HTTP
while never touching `wg0` — handing every client a config that silently cannot connect.

---

## Postgres is the source of truth

`wg0` is a cache. On boot, `WireguardService.reconcile()` makes the interface match the
database: it adds missing peers, removes peers with no device row, and re-applies peers
whose `allowed-ips` have drifted (a peer with the wrong address routes another client's
traffic).

The practical consequence: **a node is disposable.** Wipe it, re-run `provision.sh`,
restart the API, and the fleet is restored. It is also why a peer added by hand with
`ops/add-peer.sh` disappears on the next restart — it has no row, so reconciliation
removes it. That is correct behaviour, not a bug.

---

## What the cloud provider actually supplies

Nothing clever. Just a Linux machine with a public IP that stays on:

- somewhere for `wg0` to listen (UDP 51820)
- an IP address for traffic to exit from
- uptime

Oracle, AWS, Hetzner and a mini PC in an office are interchangeable here. `provision.sh`
detects the provider only to print the prerequisites that differ — Oracle's host
iptables, AWS's source/destination check, GCP's `--can-ip-forward` and lower MTU.

Nothing in `backend/src` knows or cares which one it is running on.
