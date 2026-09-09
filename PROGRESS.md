# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend only (NestJS). No Flutter work yet.
**Last updated:** 2026-09-09 (C0-C3 complete)

---

## Status

| ID | Chunk | Status |
|----|-------|--------|
| C0 | Foundation & docs | ✅ done |
| C1 | Core app | ✅ done |
| C2 | Database | ✅ done |
| C3 | Auth | ✅ done |
| C4 | Users | ⬜ not started |
| C5 | Nodes | ⬜ not started |
| C6 | WireGuard core | ⬜ not started |
| C7 | Devices | ⬜ not started |
| C8 | Hardening | ⬜ not started |
| C9 | Ops / deploy | ⬜ not started |
| C10 | Tests | ⬜ not started |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**C4 — Users**

Build in `backend/src/users/`:
- `UsersService` with `findById`, and an `activeDeviceCount(userId)` aggregation
  (`devices` where `revokedAt: null`) that C7 will reuse for the device cap
- `GET /users/me` -> `{ id, email, createdAt, deviceCount, maxDevices }`
  (`maxDevices` comes from `AppConfig.maxDevicesPerUser`)
- Route is authenticated by default; use `@CurrentUser()` to get `{ userId, email }`
- Export `UsersService` so `DevicesModule` (C7) can inject it

Small chunk. Then C5 (Nodes), then C6 (WireGuard core) — C6 is the risky one and
depends only on C2, so it can be built and tested without touching HTTP.

Verify with `npm run build`, then update this file and commit `chore(C4): users`.

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

---

## Known issues / follow-ups

- **No local Postgres.** Docker is not installed on this Mac, so the app has not yet been
  booted end to end. `npm run build` passes and the env-validation logic is verified, but
  `/health`, migrations and the seed are untested against a live database. Install Docker
  Desktop (or Postgres.app) and run `docker compose up -d && npm run prisma:deploy && npm run seed`.
- `AllExceptionsFilter` maps Prisma `P2002/P2025/P2003`. Extend if new codes show up.
- C6 must add a `wg0` **capacity check** against `Node.maxPeers` — the schema field exists
  but nothing reads it yet.
- **No refresh-token pruning yet.** `refresh_tokens` grows unbounded: every login and
  every rotation inserts a row and nothing deletes expired ones. Add a cleanup in C8
  (a scheduled job, or opportunistic deletion of rows past `expiresAt` on login).
- **Auth endpoints are not rate limited yet.** `POST /auth/login` and `/auth/register`
  are open to credential stuffing until C8 adds `@nestjs/throttler`. `@nestjs/throttler`
  is already a dependency; it is just not wired up.
- Auth was verified by unit-level checks and `npm run build`, not against a live
  database — same Docker gap as C1/C2.

---

## Deferred (explicitly out of MVP scope)

- Flutter app — separate chunk series F0–Fn, after backend is done
- iOS Network Extension target (needs paid org Apple account)
- Payments / RevenueCat, subscription tiers
- Multi-region + separate `node-agent` control plane
- Per-user bandwidth metering and quota enforcement
- Split tunnelling, kill switch, on-demand connect
