# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend only (NestJS). No Flutter work yet.
**Last updated:** 2026-09-09 (C0-C8 complete — API feature-complete and hardened)

---

## Status

| ID | Chunk | Status |
|----|-------|--------|
| C0 | Foundation & docs | ✅ done |
| C1 | Core app | ✅ done |
| C2 | Database | ✅ done |
| C3 | Auth | ✅ done |
| C4 | Users | ✅ done |
| C5 | Nodes | ✅ done |
| C6 | WireGuard core | ✅ done |
| C7 | Devices | ✅ done |
| C8 | Hardening | ✅ done |
| C9 | Ops / deploy | ⬜ not started |
| C10 | Tests | ⬜ not started |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**C9 — Ops / deploy** (where `ExecWgRunner` finally meets a real `wg` binary)

Create `docs/DEPLOY.md` plus scripts in `ops/`:

- **`ops/provision.sh`** — idempotent, run as root on a fresh Oracle Ampere box:
  - detect the NIC (`ip -br link`; OCI ARM is usually `enp0s6`) and substitute it into
    the nftables rules — do not hardcode `eth0`
  - **Oracle's double firewall**: opening the VCN Security List is not enough, the
    Ubuntu image's own iptables drops everything. Must add
    `iptables -I INPUT -p udp --dport 51820 -j ACCEPT` (and 443) then
    `netfilter-persistent save`. This is the single most common "OCI WireGuard
    silently does not work" cause.
  - `net.ipv4.ip_forward=1`, server keypair, `wg0.conf` (Address `10.7.0.1/24` +
    `fd42:7::1/64`, MTU 1420 — OCI's internet MTU is 1500 so no GCP-style reduction)
  - the nftables `vpn` table from README.md: drop `169.254.0.0/16` (OCI metadata —
    otherwise a user can steal instance credentials), drop RFC1918 destinations,
    drop SMTP, then masquerade
  - Unbound on `10.7.0.1` with `ip-freebind: yes` (it must bind before wg0 exists)
  - `vpnapi` service user + the narrow sudoers rule for `wg`/`wg-quick` only
  - Postgres 16, database + role
- **`ops/add-peer.sh`** — manual peer for testing the tunnel *before* the API is
  involved; prints a client config and a QR code
- **`ops/aegis-api.service`** — systemd unit running as `vpnapi`, `WG_RUNNER=exec`
- **`ops/Caddyfile`** — `reverse_proxy localhost:3000`, auto-TLS
- **`docs/DEPLOY.md`** — runbook: OCI instance creation (VM.Standard.A1.Flex, 2 OCPU /
  12 GB, Ubuntu 24.04, reserved public IP), Security List ingress
  (UDP 51820, TCP 443, SSH from one IP), `TRUST_PROXY=true`, `npm run prisma:deploy`,
  seed with `cat /etc/wireguard/server.pub`, and the verification checklist
  (**test from mobile data, not Wi-Fi** — consumer routers rarely hairpin NAT)

Then **C10 — Tests**: promote the throwaway harnesses used in C3/C6/C7/C8 into real
`*.spec.ts` files plus a `test/app.e2e-spec.ts`. The C8 harness (Nest booted with an
overridden `PrismaService` + supertest) is the template for the e2e file.

Verify with `npm run build` and `bash -n ops/*.sh`, then update this file and commit
`chore(C9): ops and deploy`.

---

## Decisions log

Append here as decisions are made, so a later session does not re-litigate them.

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-09 | Host: Oracle Cloud Always Free, Ampere A1 ARM, **Mumbai** | 10 TB/mo free egress; Indian exit IP; genuinely $0 |
| 2026-09-09 | Protocol: **WireGuard**, kernel module | Fast, Apache-2.0/MIT (commercial-safe), simple |
| 2026-09-09 | Backend: **NestJS 10 + Prisma + PostgreSQL 16** | User's choice |
| 2026-09-09 | MVP runs API **on the same box as `wg0`** | Avoids building a node-agent + mTLS control plane for one node. Split at multi-region. |
| 2026-09-09 | Client **generates its own X25519 keypair**; private key never leaves the device | Makes "we cannot decrypt your traffic" true, not marketing |
| 2026-09-09 | Postgres is the **source of truth** for peers; `wg0` reconciled from it on boot | Interface can be wiped/rebuilt without data loss |
| 2026-09-09 | Peer mutation via `execFile` (argv array, no shell) + strict regex validation | `publicKey` is attacker-controlled; `exec` would be a command-injection hole |
| 2026-09-09 | `WG_RUNNER=fake\|exec` switch; env validation **rejects `fake` in production** | WireGuard cannot run on macOS. A fake runner in prod would ACK peers over HTTP while never touching `wg0` — every client would get a config that cannot connect |
| 2026-09-09 | Env validated by zod at boot; app refuses to start on bad config | A misconfigured VPN control plane should fail at startup, not when a user tries to connect |
| 2026-09-09 | Refresh tokens stored as hashes with rotation + `replacedByTokenId` | A database leak must not hand out live sessions; rotation lets us detect token reuse |
| 2026-09-09 | Device revocation is a **soft delete** (`revokedAt`) | Stops a tunnel IP being recycled while a stale client may still present the old key |
| 2026-09-09 | `JwtAuthGuard` registered as a **global `APP_GUARD`**; routes opt out with `@Public()` | Secure by default — forgetting a guard locks a route down instead of exposing it |
| 2026-09-09 | Refresh tokens are **JWTs with a database row** (not opaque, not stateless) | The JWT carries signature + expiry; the row enables revocation, rotation and reuse detection. Only `sha256(token)` is stored |
| 2026-09-09 | Refresh reuse -> **revoke the user's entire token family** | A legitimate client never replays a rotated token, so reuse means theft |
| 2026-09-09 | `POST /auth/logout` is `@Public()` and takes the refresh token in the body | A client logging out usually has an expired access token; the refresh token is the credential being revoked |
| 2026-09-09 | argon2id params set **explicitly** (m=19456, t=2, p=1) | An upstream default change must not silently weaken new hashes |
| 2026-09-09 | Dummy-hash for constant-time login is **generated at boot**, not hardcoded | A malformed hash literal makes argon2 throw instantly, which returns false fast and reinstates the enumeration oracle it was meant to close |
| 2026-09-09 | Emails normalised to lowercase before storage/lookup | Otherwise `A@b.com` and `a@b.com` become two accounts |
| 2026-09-09 | `JwtStrategy.validate` does one indexed user lookup per request | A deleted account must not keep operating on a still-valid 15-minute access token |
| 2026-09-09 | `GET /nodes` omits `publicKey`, `subnetV4` and `dns` | Those only matter alongside an issued peer (returned by `POST /devices`); no reason to expose the fleet's tunnel topology to every account |
| 2026-09-09 | Device cap counts only `revokedAt: null` devices | Otherwise removing and re-adding a phone would permanently consume a slot |
| 2026-09-09 | `selectLeastLoaded()` is advisory; C6's allocator is the real capacity guard | The read can go stale between selection and insert; only the unique constraint is authoritative |
| 2026-09-09 | `WgRunner` port with `ExecWgRunner` / `FakeWgRunner` bound by `WG_RUNNER` | Lets the whole control plane be built and tested on macOS, which has no `wg` and no kernel module |
| 2026-09-09 | Peers get `allowed-ips` of **exactly `/32`** | A wider mask would let one client source-spoof another client's tunnel IP |
| 2026-09-09 | `reconcile()` re-applies a peer whose `allowed-ips` **drifted**, not just missing peers | A peer present with the wrong address routes another client's traffic |
| 2026-09-09 | `wg show <if> dump`: the **first line is the interface**, not a peer | Treating it as a peer invents a phantom peer on every reconcile and would get "removed" each time |
| 2026-09-09 | `ipToInt` uses `>>> 0` | Without it, any address with a leading octet >= 128 goes negative and range comparisons break |
| 2026-09-09 | `wg-quick save` failure is logged, not fatal | The peer is already live in the kernel and Postgres remains authoritative; failing the request would be worse |
| 2026-09-09 | Boot reconciliation failure does **not** abort startup | Existing peers keep working; the API should still serve |
| 2026-09-09 | Revoked devices keep occupying their tunnel IP | Recycling immediately would let a new device inherit traffic aimed at a stale client that has not noticed its peer is gone |
| 2026-09-09 | P2002 retry loop distinguishes `tunnelIpV4` from `publicKey` via `error.meta.target` | An IP collision is a lost race worth retrying; a duplicate public key would collide forever, so it must 409 immediately |
| 2026-09-09 | Retries bounded at 5, then 500 | An unbounded retry on a full node would spin |
| 2026-09-09 | `applyPeer` failure **deletes the device row** | Otherwise the database claims a tunnel IP that `wg0` has never heard of, and the client gets a config that silently cannot connect |
| 2026-09-09 | Revoke marks the database **before** removing the peer | `reconcile()` converges the interface onto the database, so a crash between the two steps self-heals in the safe direction. The reverse order would let reconciliation recreate a peer the user believes is gone |
| 2026-09-09 | Another user's device returns **404, not 403** | A 403 confirms the id exists; scoping the lookup by `userId` makes it indistinguishable from a nonexistent device |
| 2026-09-09 | Issued configs use `allowedIps = "0.0.0.0/0, ::/0"` | Full tunnel. Including `::/0` routes IPv6 into a tunnel the server does not forward, blackholing it rather than leaking the real address |
| 2026-09-09 | `ThrottlerGuard` registered **before** `JwtAuthGuard` | Global guards run in registration order; otherwise every throttled login attempt would still pay for an argon2 verification |
| 2026-09-09 | **One** named throttler (`default`), overridden per route with `@Throttle()` | A second named throttler applies BOTH limits to every route, which is almost never intended |
| 2026-09-09 | New `TRUST_PROXY` env var, default `false`, `true` in deployment | `false` behind Caddy collapses every user onto Caddy's IP and throttles them as one; `true` with no proxy lets a client forge `X-Forwarded-For` and bypass throttling entirely |
| 2026-09-09 | `/health` is `@SkipThrottle()` | Monitoring polls it; throttling would produce false alarms |
| 2026-09-09 | Request logging records method/path/status/duration/id — **never bodies or headers** | Auth bodies carry passwords; an endpoint that logs its own payload puts credentials into log aggregation |
| 2026-09-09 | Token pruning deletes only **expired** rows, keeps revoked-but-unexpired ones | Revoked rows are what make reuse detection work — deleting them would turn a replayed stolen token into a plain "not found" instead of a family-wide revocation |
| 2026-09-09 | Pruning runs opportunistically on login and can never fail it | Avoids adding a scheduler for one bounded indexed delete; housekeeping must not break authentication |

---

## Known issues / follow-ups

- **No local Postgres.** Docker is not installed on this Mac, so the app has not yet been
  booted end to end. `npm run build` passes and the env-validation logic is verified, but
  `/health`, migrations and the seed are untested against a live database. Install Docker
  Desktop (or Postgres.app) and run `docker compose up -d && npm run prisma:deploy && npm run seed`.
- `AllExceptionsFilter` maps Prisma `P2002/P2025/P2003`. Extend if new codes show up.
- `Node.maxPeers` is now read by `NodesService` for load and selection, but C6's
  allocator must enforce it too — selection is advisory and can race.
- ~~No refresh-token pruning~~ — done in C8 (opportunistic on login).
- ~~Auth endpoints are not rate limited~~ — done in C8 (5/min on login+register).
- **Throttler uses in-memory storage.** Fine for one instance; a second API instance
  would each keep their own counters. Swap to the Redis storage provider if the API is
  ever horizontally scaled.
- **The app now boots.** C8's harness started the full Nest DI graph with an overridden
  `PrismaService` and drove it over HTTP, so module wiring, guards, pipes, the filter
  and the throttler are all verified. What remains untested is only the real database
  layer: migrations, actual queries, and the seed.
- **`ExecWgRunner` has never been run against a real `wg` binary.** Its logic is
  verified (33 checks incl. the dump parser, via a stubbed exec), but the sudoers rule,
  binary paths and actual `wg set` behaviour are unproven until C9 deploys to the
  Oracle box. Expect to debug permissions there, not logic.
- No `updateLastSeen` yet: `Device.lastSeenAt` is never written. Wire it to
  `wg show dump` handshake timestamps in a later chunk (useful for "device inactive").

---

## Deferred (explicitly out of MVP scope)

- Flutter app — separate chunk series F0–Fn, after backend is done
- iOS Network Extension target (needs paid org Apple account)
- Payments / RevenueCat, subscription tiers
- Multi-region + separate `node-agent` control plane
- Per-user bandwidth metering and quota enforcement
- Split tunnelling, kill switch, on-demand connect
