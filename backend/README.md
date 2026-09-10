# Aegis VPN — Backend

NestJS control plane. Issues WireGuard peers, manages users and devices.

## Local development (macOS)

You cannot run WireGuard on macOS, so local dev uses a **fake peer driver**
(`WG_RUNNER=fake`) — the API behaves identically but keeps peers in memory instead of
calling `wg`. All HTTP, auth, database, and IP-allocation logic is fully exercised.

```bash
cp .env.example .env
```

Generate the two JWT secrets (they must differ):

```bash
openssl rand -base64 48
```

Start Postgres and the API:

```bash
docker compose up -d
npm install
npm run prisma:migrate
npm run seed
npm run start:dev
```

Check it's alive:

```bash
curl http://localhost:3000/health
```

## Production

`WG_RUNNER=exec` on the VPN node, which calls the real `wg` binary through a
narrow sudoers rule. See `docs/DEPLOY.md` (chunk C9).

## Configuration

Every variable is documented in [`.env.example`](.env.example) and validated at boot by
`src/config/env.validation.ts` — the app refuses to start with a missing or malformed
value rather than failing later at runtime.

Two that matter most:

| Variable | Note |
|---|---|
| `WG_RUNNER` | `fake` for local dev, `exec` in production. **Never `fake` in production** — peers would be accepted by the API but never actually added to the interface. |
| `MAX_DEVICES_PER_USER` | Enforced on `POST /devices`. Without a cap, accounts get shared and one user can exhaust a node's `/24`. |

## API surface

| Method | Path | Auth | Chunk |
|---|---|---|---|
| GET | `/health` | — | C1 |
| POST | `/auth/register` | — | C3 |
| POST | `/auth/login` | — | C3 |
| POST | `/auth/refresh` | refresh token | C3 |
| POST | `/auth/logout` | ✅ | C3 |
| GET | `/users/me` | ✅ | C4 |
| GET | `/nodes` | ✅ | C5 |
| GET | `/devices` | ✅ | C7 |
| POST | `/devices` | ✅ | C7 |
| DELETE | `/devices/:id` | ✅ | C7 |

## Layout

```
src/
├── main.ts
├── app.module.ts
├── config/          # typed env loading + boot-time validation
├── prisma/          # PrismaService (lifecycle-managed client)
├── common/          # guards, decorators, filters, DTO helpers
├── health/
├── auth/
├── users/
├── nodes/
├── wireguard/       # WgRunner port, WireguardService, IpAllocatorService
└── devices/
```
