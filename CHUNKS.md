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

**Backend is complete after C10.** Flutter work is intentionally out of scope for now and
will get its own chunk series (F0–Fn) later.

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
