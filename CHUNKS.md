# Aegis VPN — Chunked Build Plan

This project is built in **self-contained chunks** so work can stop and resume at any
point without losing context. Each chunk leaves the repo in a compiling, committed state.

## How to resume in a new session

1. Open Claude Code in this folder: `~/StudioProjects/aegis-vpn`
2. Say exactly:

   ```
   Read PROGRESS.md and build the next chunk.
   ```

   Or to target a specific one:

   ```
   Read PROGRESS.md and build chunk C5.
   ```

3. Claude reads `PROGRESS.md` (the live state file), sees what is done, and continues.

**That is the whole protocol.** `PROGRESS.md` is the source of truth — it is updated at the
end of every chunk with what landed, what is next, and any decisions made along the way.

> If you are the assistant reading this: after finishing a chunk you MUST update
> `PROGRESS.md` (status table + "Next chunk" + any new decisions) and commit. Do not
> start a chunk without reading `PROGRESS.md` first.

---

## Chunk list

| ID | Name | What it delivers | Depends on |
|----|------|------------------|------------|
| **C0** | Foundation & docs | Repo layout, `package.json`, `tsconfig`, `.env.example`, `.gitignore`, README, this file, `PROGRESS.md` | — |
| **C1** | Core app | `main.ts`, `AppModule`, typed+validated config, `PrismaModule/Service`, `/health`, global pipes & filters, **`prisma/schema.prisma`** | C0 |
| **C2** | Database | Initial migration SQL, idempotent seed script | C1 |
| **C3** | Auth | argon2 hashing, `POST /auth/register|login|refresh|logout`, `JwtStrategy`, `JwtAuthGuard`, `@CurrentUser()`, refresh rotation | C2 |
| **C4** | Users | `GET /users/me`, user service, device-count aggregation | C3 |
| **C5** | Nodes | `GET /nodes` server list with load/capacity, `NodesService` | C3 |
| **C6** | WireGuard core | `WgRunner` port (real `execFile` + fake for macOS dev), `WireguardService`, `IpAllocatorService`, boot reconciliation | C2 |
| **C7** | Devices | `POST /devices` (issue peer + return client config), `GET /devices`, `DELETE /devices/:id`, device cap | C5, C6 |
| **C8** | Hardening | rate limiting, helmet, CORS, structured logging, request-id, global exception filter | C7 |
| **C9** | Ops / deploy | `provision.sh`, `add-peer.sh`, systemd unit, `Caddyfile`, deployment runbook | C7 |
| **C10** | Tests | Unit tests (IP allocator, key validation, config assembly) + e2e smoke test | C8 |

**Backend is complete after C10.** The Flutter client is the F series (F0–F7); going
multi-country is the M series below.

---

## Multi-region series (M0–M3)

Adding a second country is not a data problem. `Node` already carries its own region,
subnet, key, endpoint and capacity per row; `GET /nodes` already reports a fleet with
per-node load; `IpAllocatorService` already allocates inside one node's subnet under a
`@@unique([nodeId, tunnelIpV4])` guard; and the client already reads regions as
countries and can switch between them.

It is a control-plane problem, and it is one line wide. `WireguardService.applyPeer`
takes the chosen node, validates the address against that node's subnet — and then
calls a single module-scoped runner that shells out to `wg set` on *the host the API is
running on*. Add a Germany row today and the client is issued a correct-looking Germany
config whose peer is written to Mumbai's `wg0`. Frankfurt never learns the key, the
handshake never completes, and the app reports "Not verified" forever.

| ID | Name | What it delivers | Depends on |
|----|------|------------------|------------|
| **M0** | Node-aware control plane | `WG_NODE_ID`, per-node runner resolution, `revokePeer`/`reconcile` scoped to a node, and a loud failure for any node the API has no way to reach | C7 |
| **M1** | Node agent | Agent entrypoint on the same backend artifact, bearer-authenticated peer API, `HttpWgRunner`, `Node.agentUrl`/`agentToken`, systemd unit and env template | M0 |
| **M2** | Second node | Provision a node in another country, seed its row, wire its agent credentials, make `SERVER-OPS.md` fleet-aware | M1 |
| **M3** | What "automatic" means | Replace free-slot selection with something defensible once nodes are in different countries | M2 |

### Decisions taken for this series

**An agent, not SSH.** The alternative was an `SshWgRunner` that runs `wg set` over SSH
— far less to build, but the API would then hold keys with `sudo wg` rights on every
node in the fleet, so one API compromise is every exit node. The agent keeps the blast
radius to a single interface.

**The agent is the same artifact, not a second project.** It is a second entrypoint on
the backend build (`node dist/agent/main`), so it reuses `ExecWgRunner` and
`wg-validation` verbatim rather than reimplementing the one part of this system where a
parsing mistake is a security incident. Deploy the same tarball everywhere; the API runs
one entrypoint and every node runs the other.

**The agent gets no database and no JWT secrets.** It validates its own narrow
environment — interface, binaries, bearer token, bind address — and nothing else, so
compromising a node yields control of that node's interface and no more. This is the
whole reason it is not simply "run the API on every node".

**Locality is explicit.** A node is programmed locally only when its id matches
`WG_NODE_ID`. Anything else needs an `agentUrl`, and a node with neither fails with a
clear error rather than silently programming the wrong interface — which is exactly the
bug this series exists to remove. `WG_NODE_ID` is optional only while the fleet has one
active node, so the existing single-node deployment keeps working untouched.

**M3 is a product decision, not a refactor.** `selectLeastLoaded()` sorts by free slots,
which is meaningless across countries — it will route a Mumbai user to Frankfurt the
moment Frankfurt is emptier, under a button the client labels "Fastest available".
Nearest (geo-IP at the API), fastest (client-side probing) and least-loaded are three
different products; it is left open deliberately rather than guessed at.

---

## Chunk rules

Every chunk must:

1. **Compile.** `npm run build` passes before the chunk is considered done.
2. **Be committed.** One git commit per chunk, message `chore(Cn): <name>`.
3. **Update `PROGRESS.md`** — status table, "Next chunk", and any decisions/deviations.
4. **Touch only its own scope.** No drive-by refactors of earlier chunks. If an earlier
   chunk needs a fix, log it under "Known issues / follow-ups" in `PROGRESS.md`.
5. **Leave no stubs that silently fail.** Unimplemented paths throw explicitly.

---

## Why this order

- **C6 (WireGuard) depends only on C2**, not on auth — so the risky, platform-specific
  part can be built and tested in isolation, without HTTP or JWTs in the way.
- **C3 (auth) comes before C7 (devices)** because device issuance is meaningless without
  a user identity to attach a peer to.
- **C9 (ops) is late** because the provisioning script needs the final env-var surface.
- **C10 (tests) is last** but the IP allocator and key-validation logic in C6 are the ones
  that actually matter — those are the two places a bug becomes a security or
  correctness incident.

---

## Deviations from the original plan

**C1 absorbed `prisma/schema.prisma` (planned for C2).** Prisma refuses to run
`generate` against a schema with zero models, and `PrismaService extends PrismaClient`
cannot compile without a generated client. So the schema is a hard build dependency of
C1, not something C2 could add later. C2 kept the migration SQL and the seed script.

**The initial migration was generated offline** with
`prisma migrate diff --from-empty --to-schema-datamodel`, because there was no local
Postgres available at build time. It is a normal Prisma migration and
`prisma migrate deploy` applies it as usual.
