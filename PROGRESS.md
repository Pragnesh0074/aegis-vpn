# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend **done** and one node live. Flutter client **done** and
**handshaking against the live node**. Next up is the M series: making the control plane
able to program more than one node. iOS is deliberately deferred.
**Last updated:** 2026-09-11 (M0-M1 deployed to Mumbai; Frankfurt live, held inactive pending its SG rule)

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
| C9 | Ops / deploy | ✅ done |
| C10 | Tests | ✅ done |
| F0 | Client core (config, Dio, interceptor, session, router, theme) | ✅ done |
| F1 | Client auth (register / login / refresh / logout) | ✅ done |
| F2 | Client profile (`/users/me`) | ✅ done |
| F3 | Client nodes (`/nodes`) | ✅ done |
| F4 | Client devices (keygen, issue, list, revoke) | ✅ done |
| F5 | Client health + tabbed shell | ✅ done |
| F6 | Platform VPN tunnel — Android (`VpnService` via wireguard-android) | ✅ done |
| F7 | Platform VPN tunnel — iOS (Network Extension) | ⬜ deferred |
| M0 | Node-aware control plane (`WG_NODE_ID`, per-node runner) | ✅ done |
| M1 | Node agent (entrypoint, `HttpWgRunner`, agent columns, systemd unit) | ✅ done |
| M2 | Second node (Frankfurt) | 🟡 both nodes live, awaiting one SG rule |
| M3 | What "automatic" means across countries | ⬜ not started |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**Finish M2.** The Frankfurt exit node is built, provisioned and serving its agent.
The remaining work is all on the Mumbai side, which was unreachable when this was
done — every port including 80/443 was closed and ICMP was silent, which points at
a stopped instance rather than a security-group rule.

### Fleet as it stands

| | Mumbai #1 | Frankfurt #1 |
|---|---|---|
| id | `501b27c5-59d2-48ac-a4d1-4e2af3a8a86d` | `a0047e7d-2f56-4370-8776-61170ececf9c` |
| region | `in-mumbai` | `de-frankfurt` |
| endpoint | `13.126.153.247:51820` | `3.71.204.118:51820` |
| subnet | `10.8.0.0/24` | `10.9.0.0/24` |
| role | control (API + agent-less, programmed locally) | exit (`NODE_ROLE=exit`, agent on :8787) |
| active | `true` | **`false`** — deliberately |

Frankfurt is held inactive on purpose. Two active nodes while Mumbai still runs
pre-M0 code means `selectLeastLoaded()` can choose Frankfurt while the peer is
written to Mumbai's interface, which is the exact silent failure this series
removes. Activate it only after step 3 below.

### To finish

Mumbai now runs M0/M1 with `WG_NODE_ID` set; boot reconciliation resolved its own
node correctly (`Reconciled wg0: +0 -0 =4`). One thing blocks activation:

1. **Frankfurt's security group still whitelists Mumbai's old address** for TCP
   8787. Mumbai moved from `13.201.194.65` to `13.126.153.247` when it was
   restarted without an Elastic IP, so `curl` from Mumbai to the agent times out.
   Update the rule to `13.126.153.247/32`.
2. **Then activate Frankfurt**:
   `update nodes set active = true where region = 'de-frankfurt';`

Do not reverse that order. `selectLeastLoaded()` ranks by free slots, so the
moment Frankfurt is active it becomes the default choice for every new device —
Frankfurt has 250 free against Mumbai's 246. With the agent unreachable, each of
those issues would fail with a 503 instead of quietly landing on the wrong
interface. That is the M0 behaviour working as designed, but it still means every
new signup breaks until the rule is fixed.

3. **Verify**: connect from the app choosing Germany, then on the Frankfurt box
   confirm `sudo wg show wg0` reports a real `latest handshake`.

### Neither instance has an Elastic IP

Accepted for the MVP, but every stop/start changes both addresses and each change
breaks four things: the `nodes.endpoint`, the `agentUrl`, the Frankfurt SG rule,
and `_defaultBaseUrl` in `app/lib/core/config/app_config.dart` (which needs an APK
rebuild). Existing devices cannot recover at all, because the endpoint is only ever
returned by `POST /devices`. An Elastic IP costs the same as the ephemeral address
already being billed; the alternative is a domain plus a dynamic-DNS updater.

Then **M3**: decide what "automatic" means now that two countries exist.
`selectLeastLoaded()` sorts by free slots, so it will send a Mumbai user to
Frankfurt the moment Frankfurt is emptier — under a button the client labels
"Fastest available".

Also open: **iOS (F7)**, not started on purpose — a Network Extension needs a paid
organization Apple account. `app/ios/` is the untouched Flutter scaffold, and the
Dart side is already platform-agnostic behind `TunnelChannel`.

To continue, say: `Read PROGRESS.md and finish M2.`

---

## Decisions log

Append here as decisions are made, so a later session does not re-litigate them.

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-11 | The Frankfurt instance arrived as an **AMI clone of Mumbai** and was rebuilt, not adopted | It carried Mumbai's WireGuard *private* key, Mumbai's four peers, Mumbai's `api.env` (Supabase password + both JWT secrets), Mumbai's SSH key, and a running second `aegis-api` against the same database. A node row built from it would have duplicated Mumbai's public key, leaving clients unable to distinguish the two. Fresh keypair, peers wiped, API disabled, copied secrets deleted; the originals are in `/root/pre-rebuild-backup` |
| 2026-09-11 | **One tunnel subnet per node**: Mumbai `10.8.0.0/24`, Frankfurt `10.9.0.0/24` | `@@unique([nodeId, tunnelIpV4])` is per-node so overlap would not error, but it makes every log line ambiguous about which country an address belongs to, and rules out node-to-node routing later |
| 2026-09-11 | `provision.sh` gained `NODE_ROLE` and overridable `TUNNEL_NET` | It assumed one all-in-one box. An exit node must not install PostgreSQL — the database is Supabase and the agent holds no database credentials, so a local one is pure attack surface. Parameterised rather than forked, so the two paths cannot drift |
| 2026-09-11 | Agent runs **plaintext on `0.0.0.0:8787`, security-group-locked to the API's IP** | Interim, and agreed as such: there is no domain yet, so Caddy cannot obtain a certificate, and the whole API is currently plain HTTP anyway. The bearer token therefore crosses the public internet in the clear. Must move behind TLS before real users — a domain fixes this and the API's HTTP at once |
| 2026-09-11 | A new node is seeded **`active = false`** and activated last | While the API still runs pre-M0 code, two active nodes let `selectLeastLoaded()` pick the new one while the peer is written to the old one's interface. Activating last makes the dangerous window zero |
| 2026-09-11 | Remote nodes are programmed by an **agent over HTTP**, not by SSH from the API | An `SshWgRunner` was far less to build, but the API would hold keys with `sudo wg` rights on every exit node, so one API compromise is the whole fleet. The agent keeps the blast radius to one interface |
| 2026-09-11 | The agent is a **second entrypoint on the backend artifact**, not a separate project | It reuses `ExecWgRunner` and `wg-validation` verbatim rather than reimplementing the one part of this system where a parsing mistake is a security incident. One tarball deploys everywhere |
| 2026-09-11 | The agent validates its **own narrow environment** — no `DATABASE_URL`, no JWT secrets | Compromising an exit node must yield that node's interface and nothing else. This is the reason the design is not simply "run the whole API on every node" |
| 2026-09-11 | A node is programmed locally **only if its id matches `WG_NODE_ID`**; anything else needs an `agentUrl`, and a node with neither throws | The bug this series removes is silent misprogramming — issuing a valid-looking Germany config whose peer lands on Mumbai's `wg0`. Failing loudly is the whole point |
| 2026-09-11 | `WG_NODE_ID` is **optional while exactly one node is active** | Keeps the running single-node deployment working untouched; it becomes required the moment a second node exists, which is exactly when ambiguity would start to matter |
| 2026-09-11 | Agent credentials (`agentUrl`, `agentToken`) live on the **node row**, not in env | Per-node tokens can be rotated independently without redeploying the API, and adding a node is then a data change. The trade-off accepted: a database compromise exposes every agent token — but that database already holds refresh-token hashes and is game over regardless |
| 2026-09-11 | Peer removal is `POST /peers/remove`, not `DELETE /peers/:key` | A WireGuard public key is base64 and contains `/`, `+` and `=`. Putting it in a path segment invites proxy and encoding bugs on the one call whose failure silently leaves a revoked peer live |
| 2026-09-09 | ~~Host: Oracle Cloud Always Free, Ampere A1 ARM, Mumbai~~ | superseded 2026-09-10 |
| 2026-09-10 | **Host: AWS EC2** (Graviton ARM64), user's choice | Ops layer is now provider-agnostic; `provision.sh` detects the cloud from the metadata service and prints provider-specific prerequisites. **No application code changed** — the API never knew which cloud it was on |
| 2026-09-10 | AWS **source/destination check must be disabled** — the one mandatory AWS-only step | EC2 silently discards forwarded packets otherwise. Symptom is a successful handshake followed by no traffic, which looks identical to an MTU or NAT fault. Cannot be set from inside the instance, so the script can only remind |
| 2026-09-10 | Egress cost accepted as a known trade-off | AWS charges ~$0.09/GB vs Oracle's 10 TB/mo free. Irrelevant at MVP scale; at 1,000 users (~20 TB/mo) it is ~$1,790/mo vs ~$85. The fix when it matters is moving **exit nodes** to a flat-rate host — a node is just a `nodes` row plus a `provision.sh` run, so no rearchitecture |
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
| 2026-09-09 | `provision.sh` never overwrites `wg0.conf` or `server.key` | Regenerating the server key invalidates every issued peer; overwriting the conf drops saved `[Peer]` blocks |
| 2026-09-09 | nftables table written to `/etc/nftables.d/aegis-vpn.nft` and `include`d | Appending to `nftables.conf` would stack a duplicate table on every re-run |
| 2026-09-09 | NIC detected from the default route, never hardcoded | OCI ARM is `enp0s6`, AWS `ens5`, GCP `ens4`; a wrong `oifname` means handshake succeeds but no traffic flows |
| 2026-09-09 | iptables rules added with a `-C` guard | `-I` alone stacks duplicates on every provision run |
| 2026-09-09 | systemd unit **omits** `NoNewPrivileges` and `ProtectSystem=strict` | Both break the sudo escalation the API needs for `wg` — `NoNewPrivileges` forbids setuid outright, and `ProtectSystem=strict` makes `/etc` read-only for sudo children, so `wg-quick save` fails. The sudoers allowlist is the compensating control |
| 2026-09-09 | `add-peer.sh` avoids `mapfile` | `mapfile` is bash 4+; if unavailable the used-address array is empty and the script hands out `.2` on top of a live peer. A string + `grep -qxF` cannot fail open |
| 2026-09-09 | `/etc/aegis/api.env` is mode `640 root:vpnapi` | Holds the database password and both JWT secrets |
| 2026-09-09 | **Database moved to Supabase** (`ap-northeast-2`, pooled) — set up by the user, not by these chunks | Managed backups and no Postgres to run on the node. Requires `directUrl` in `schema.prisma`: queries go over pgbouncer, but migrations need a direct connection because pgbouncer in transaction mode cannot hold DDL advisory locks |
| 2026-09-09 | `DIRECT_URL` added to env validation as **optional** | Only needed behind a pooler; a local/direct Postgres does not use it |
| 2026-09-09 | Tests compile against `tsconfig.spec.json` with `strict: false` | Lets partial mocks be written inline without a wall of casts. `tsconfig.build.json` excludes `*.spec.ts`, so nothing shipped is built with the relaxation |
| 2026-09-09 | e2e clears throttler storage in `beforeEach` | Counters are per-process, so a flooding test leaves that route limited for every later test. Found the hard way: the guard-ordering test broke the error-shape assertion |
| 2026-09-09 | `Logger.overrideLogger(false)` in the unit test setup | Several specs exercise error paths deliberately; their logs looked like failures |

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
- ~~Never run against a real database~~ — **closed.** The API was booted against live
  Supabase and driven through the whole flow: register, duplicate-email 409,
  `/users/me`, `/nodes`, two device issuances (`10.7.0.2/32` then `10.7.0.3/32`),
  duplicate-publicKey 409, `GET /devices`, refresh rotation, **refresh-reuse theft
  detection with family revocation**, and `DELETE /devices/:id`. Test data was removed
  afterwards (0 users / 0 devices / 0 tokens; the seeded node kept).
- **`ExecWgRunner` has still never run against a real `wg` binary.** C9 wrote the
  provisioning and the sudoers rule, but nothing has been executed on an actual cloud
  instance. The scripts pass `bash -n` and the address-selection logic is unit-tested,
  but package installs, `netfilter-persistent`, the Postgres role setup and the sudo
  escalation are all unverified. First real deploy will surface issues — expect
  permissions and paths, not logic.
- `provision.sh` was not executed anywhere (it needs root on Ubuntu). Syntax checked
  only. `shellcheck` is not installed on the dev machine; worth running once before
  the first deploy.
- **`provision.sh` and `DEPLOY.md` still install and configure local PostgreSQL**,
  which is now redundant because the database is on Supabase. Harmless but wasteful;
  trim when deploying, or leave it as a fallback path.
- **Supabase region is `ap-northeast-2` (Seoul).** If the EC2 instance is not also in
  Seoul, this applies: Every authenticated request does one indexed user lookup in
  `JwtStrategy.validate`, so each API call pays a Seoul round-trip (~80-120 ms from
  India). Fine for the MVP, but consider a Mumbai/Singapore Supabase project, or
  caching the user lookup, before this carries real traffic.
- Supabase free-tier projects pause after ~7 days of inactivity; the first request
  after that will time out until the project resumes.
- No `updateLastSeen` yet: `Device.lastSeenAt` is never written. Wire it to
  `wg show dump` handshake timestamps in a later chunk (useful for "device inactive").

---

## Deferred (explicitly out of MVP scope)

- iOS Network Extension target (F7 — needs paid org Apple account)
- Payments / RevenueCat, subscription tiers
- Multi-region + separate `node-agent` control plane
- Per-user bandwidth metering and quota enforcement
- Split tunnelling, kill switch, on-demand connect
