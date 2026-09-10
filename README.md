# Aegis VPN

A self-hosted WireGuard VPN — your own servers, your own keys, no reseller in the middle.

| | |
|---|---|
| **Backend** | NestJS 10 · TypeScript · Prisma · PostgreSQL (Supabase) |
| **Tunnel** | WireGuard (kernel module) · nftables · Unbound |
| **Host** | AWS EC2 (Graviton ARM64) or Oracle Cloud Ampere — see `docs/DEPLOY.md` |
| **Client** | Flutter · Riverpod 3 · Dio · go_router — see `app/README.md` |

## Repo layout

```
aegis-vpn/
├── CHUNKS.md      # the build plan, chunk by chunk
├── PROGRESS.md    # live state — read this first
├── README.md
├── backend/       # NestJS API
└── app/           # Flutter client
```

## Building this project

Work is split into resumable chunks. To continue in a fresh session, open Claude Code
in this folder and say:

```
Read PROGRESS.md and build the next chunk.
```

See [CHUNKS.md](CHUNKS.md) for the full plan and [PROGRESS.md](PROGRESS.md) for current state.

## Architecture (MVP)

Everything except the database runs on one instance. The API is cloud-agnostic —
only `ops/` and `docs/` know which provider you are on.

```
 Flutter app ──HTTPS──> Caddy :443 ──> NestJS :3000 ──> PostgreSQL
                                            │
                                            └── execFile('wg set wg0 …')
                                                          │
 Flutter app ──UDP 51820──────────────────────────────> wg0
```

### Security invariants

These are load-bearing. Do not break them without updating the decisions log.

1. **The client generates its own keypair.** Only the *public* key is ever sent to the API.
   The private key lives in Keychain / Android Keystore and never touches a server.
2. **Postgres is the source of truth for peers.** `wg0` is reconciled from the database on
   every boot, so the interface is disposable.
3. **Peer mutations use `execFile` with an argv array** (no shell) plus strict regex
   validation. `publicKey` is attacker-controlled input.
4. **The nftables egress chain blocks** cloud metadata (`169.254.0.0/16`), RFC1918
   destinations, and SMTP. Without the first two, a user can reach the instance metadata
   endpoint and steal cloud credentials.
5. **Unbound runs on the node** so DNS never leaves the tunnel.

## Docs

- [`CHUNKS.md`](CHUNKS.md) — build plan and chunk rules
- [`PROGRESS.md`](PROGRESS.md) — status, decisions log, follow-ups
- `backend/README.md` — API setup and local development
- `docs/DEPLOY.md` — server provisioning runbook (chunk C9)
