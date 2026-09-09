# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend only (NestJS). No Flutter work yet.
**Last updated:** 2026-09-09 (C0-C6 complete)

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
| C7 | Devices | ⬜ not started |
| C8 | Hardening | ⬜ not started |
| C9 | Ops / deploy | ⬜ not started |
| C10 | Tests | ⬜ not started |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**C7 — Devices** (the payoff chunk: ties C5 + C6 together behind HTTP)

Build in `backend/src/devices/`:
- `POST /devices` — body `{ publicKey, name, platform, nodeId? }`
  1. `UsersService.hasDeviceCapacity(userId)` -> 409 if the cap is hit
  2. node = `nodeId ? findActiveOrThrow : selectLeastLoaded()`
  3. **allocate + insert with retry**: `WireguardService.allocateIp(node)` then
     `device.create`. On Prisma `P2002` (the `@@unique([nodeId, tunnelIpV4])`
     constraint firing on a concurrent insert) re-allocate and retry, max ~5 times.
     The allocator is advisory — this retry loop is what actually makes it safe.
  4. `WireguardService.applyPeer(device, node)`
  5. **If applyPeer throws, delete the row** so the database cannot claim an address
     the interface does not have.
  6. return the client config (see below)
- `GET /devices` — the user's active devices (never the tunnel topology of others)
- `DELETE /devices/:id` — verify ownership, `revokePeer`, set `revokedAt`
  (soft delete: do NOT free the IP immediately)
- Also reject a `publicKey` already registered (unique constraint -> 409)

`POST /devices` response shape — everything the client needs except the private key:
```json
{ "deviceId": "...", "tunnelIp": "10.7.0.7/32", "dns": "10.7.0.1", "mtu": 1420,
  "peer": { "publicKey": "<node.publicKey>", "endpoint": "vpn.example.com:51820",
            "allowedIps": "0.0.0.0/0, ::/0", "persistentKeepalive": 25 } }
```
`persistentKeepalive: 25` is mandatory for mobile — carrier NAT drops idle tunnels
after ~30-60s and reconnects look broken without it.

Verify with `npm run build` plus a `FakeWgRunner` exercise of the P2002 retry path and
the applyPeer-failure rollback, then update this file and commit `chore(C7): devices`.

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

---

## Known issues / follow-ups

- **No local Postgres.** Docker is not installed on this Mac, so the app has not yet been
  booted end to end. `npm run build` passes and the env-validation logic is verified, but
  `/health`, migrations and the seed are untested against a live database. Install Docker
  Desktop (or Postgres.app) and run `docker compose up -d && npm run prisma:deploy && npm run seed`.
- `AllExceptionsFilter` maps Prisma `P2002/P2025/P2003`. Extend if new codes show up.
- `Node.maxPeers` is now read by `NodesService` for load and selection, but C6's
  allocator must enforce it too — selection is advisory and can race.
- **No refresh-token pruning yet.** `refresh_tokens` grows unbounded: every login and
  every rotation inserts a row and nothing deletes expired ones. Add a cleanup in C8
  (a scheduled job, or opportunistic deletion of rows past `expiresAt` on login).
- **Auth endpoints are not rate limited yet.** `POST /auth/login` and `/auth/register`
  are open to credential stuffing until C8 adds `@nestjs/throttler`. `@nestjs/throttler`
  is already a dependency; it is just not wired up.
- Auth was verified by unit-level checks and `npm run build`, not against a live
  database — same Docker gap as C1/C2.
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
