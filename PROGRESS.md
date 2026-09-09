# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend only (NestJS). No Flutter work yet.
**Last updated:** 2026-09-09

---

## Status

| ID | Chunk | Status |
|----|-------|--------|
| C0 | Foundation & docs | ⬜ not started |
| C1 | Core app | ⬜ not started |
| C2 | Database | ⬜ not started |
| C3 | Auth | ⬜ not started |
| C4 | Users | ⬜ not started |
| C5 | Nodes | ⬜ not started |
| C6 | WireGuard core | ⬜ not started |
| C7 | Devices | ⬜ not started |
| C8 | Hardening | ⬜ not started |
| C9 | Ops / deploy | ⬜ not started |
| C10 | Tests | ⬜ not started |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**C0 — Foundation & docs**

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

---

## Known issues / follow-ups

- (none yet)

---

## Deferred (explicitly out of MVP scope)

- Flutter app — separate chunk series F0–Fn, after backend is done
- iOS Network Extension target (needs paid org Apple account)
- Payments / RevenueCat, subscription tiers
- Multi-region + separate `node-agent` control plane
- Per-user bandwidth metering and quota enforcement
- Split tunnelling, kill switch, on-demand connect
