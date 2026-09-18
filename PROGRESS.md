# PROGRESS — live state

> **Assistant: read this file first, every session.** It is the source of truth for what
> exists and what comes next. Update it at the end of every chunk, then commit.

**Project:** Aegis VPN — self-hosted WireGuard VPN
**Scope right now:** backend **done** and two nodes live. Flutter client **done** and
**handshaking against the live fleet**. The M series is complete: the control plane
programs more than one node, and "automatic" now means the node nearest the user
rather than the emptiest one. iOS is deliberately deferred.
**Last updated:** 2026-09-15 (M3, last-seen, exit check, split tunnelling, auto-connect,
history, quick-settings tile, node health + failover)

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
| M2 | Second node (Frankfurt) | ✅ done |
| M3 | What "automatic" means across countries | ✅ done |
| K1 | Kill switch (auto-reconnect + system lockdown guidance) | ✅ done |
| D1 | `Device.lastSeenAt` written from peer handshakes | ✅ done |
| V1 | Exit verification (`GET /whoami` + connect-screen check) | ✅ done — card restored when the self-exclusion was reverted |
| S1 | Split tunnelling (per-app exclusions) | ✅ done |
| A1 | Auto-connect on untrusted Wi-Fi | ✅ done |
| H1 | Session history (on-device) | ✅ done |
| Q1 | Quick Settings tile | ✅ done |
| N1 | Node health + failover | ✅ done |
| B1 | Ad/tracker blocking (Blocky in front of Unbound, node-side) | ✅ done — live on Mumbai |
| B2 | Per-user ad-blocking switch (settings toggle, paid-plan seam) | ✅ done — live on Mumbai |
| B3 | ~~Rewarded ad buys 5 min of ad blocking~~ | ❌ removed 2026-09-18 — see decisions log |
| U1 | Protection page folded into Account, plain-language settings | ✅ built — app rebuild pending |

Legend: ⬜ not started · 🟡 in progress · ✅ done

## Next chunk

**Deploy what is on this branch.** M3, D1 and V1 are written and tested but only
against the local suite — none of it has run on Mumbai. Three things have to reach
the node together:

1. `GET /whoami` is new, and the client calls it on the connect screen. Against a
   backend without it the call 404s and the card reads "Could not check your exit
   address", which is honest but useless — so the API goes out before, or with, an
   app build.
2. `DEVICE_LAST_SEEN_POLL_SECONDS` is a new env var (default 60). The sweep it
   drives reads peers **through the registry**, so `WG_NODE_ID` must be set on
   Mumbai or every sweep logs a warning per node and writes nothing.
3. Nothing in this branch touches the database schema, so there is no migration.

Then watch one thing on the first run: the sweep asks Frankfurt's agent for its
peers every 60s over the plaintext, security-group-locked link. That is the first
recurring API→agent traffic in the system; everything before it was per-request.

**And put S1, A1, H1 and Q1 on a real phone.** None of the four has met a device.
The things most likely to break there, in order: the location permission flow
behind auto-connect's SSID read, a tunnel built with a non-empty excluded set,
whether the in-process network callback fires while the app is backgrounded
rather than only while it is on screen, and the tile's cold-start path — tapping
it with the app not running should launch Aegis and connect without a second tap.

### Fleet as it stands

| | Mumbai #1 | Frankfurt #1 |
|---|---|---|
| id | `501b27c5-59d2-48ac-a4d1-4e2af3a8a86d` | `a0047e7d-2f56-4370-8776-61170ececf9c` |
| region | `in-mumbai` | `de-frankfurt` |
| endpoint | `3.110.119.193:51820` | `3.71.204.118:51820` |
| subnet | `10.8.0.0/24` | `10.9.0.0/24` |
| role | control (API + agent-less, programmed locally) | exit (`NODE_ROLE=exit`, agent on :8787) |
| active | `true` | `true` |

Frankfurt is held inactive on purpose. Two active nodes while Mumbai still runs
pre-M0 code means `selectLeastLoaded()` can choose Frankfurt while the peer is
written to Mumbai's interface, which is the exact silent failure this series
removes. Activate it only after step 3 below.

### Verified end to end on 2026-09-11

Against the live fleet, through the API on Mumbai:

```
POST /devices  nodeId=<frankfurt>   ->  tunnelIp 10.9.0.2/32
                                        node Frankfurt #1 (de-frankfurt)
                                        endpoint 3.71.204.118:51820
frankfurt wg0: peer present, allowed ips 10.9.0.2/32
mumbai    wg0: peer absent (0 occurrences)
DELETE /devices/:id -> 204, peer removed from frankfurt wg0
```

That is the M series' whole purpose demonstrated: a peer for a node the API is
not running on was installed on *that* node's interface, and revoking it removed
it from there. Before M0 both operations hit Mumbai's `wg0` regardless of the
node chosen.

`GET /nodes` returns both countries, and the client renders them as India and
Germany with flags (pinned by `test/unit/fleet_render_test.dart`).

### What M3 decided

"Automatic" means **the nearest node with capacity**, ranked on the client from
the device's UTC offset, and the button says "Closest to you" instead of "Fastest
available". The app now sends an explicit `nodeId` on `POST /devices` rather than
letting the server choose; `selectLeastLoaded()` stays as the fallback for a
request that names no node.

Neither obvious way of doing this properly was available, which is why the answer
is an estimate:

- **Timing a probe** needs something on the node that answers. WireGuard is silent
  to unauthenticated packets by design, so `:51820` cannot be timed, and the only
  other listener is the agent — whose port is locked to the API's address and is
  not going to be opened to the internet to measure a round trip.
- **Geolocating the client's address** server-side means shipping a GeoIP database
  or sending a VPN user's real address to a third-party lookup. The second is
  disqualified by what this product is for.

So the client estimates a longitude from its own time zone and compares it against
country centroids, in bands one hour of longitude wide, preferring the emptier node
within a band. It is coarse and the locations screen says so in as many words.

Also open: **iOS (F7)**, not started on purpose — a Network Extension needs a paid
organization Apple account. `app/ios/` is the untouched Flutter scaffold, and the
Dart side is already platform-agnostic behind `TunnelChannel`.

To continue, say: `Read PROGRESS.md and finish M2.`

---

## Decisions log

Append here as decisions are made, so a later session does not re-litigate them.

| 2026-09-18 | **The rewarded-ad experiment is removed**, and with it the self-exclusion and the AdMob allowlist | It never worked through the tunnel. Three real bugs were found and fixed along the way — AAAA blackholing, the app's routing, a sinkholed ad host — and after each one it still failed. The last state was the honest one: the app was excluded, no ad traffic crossed the tunnel at all (verified by a 75s capture during an ad attempt), and the ad still would not load. What remained was a choice with no good side: `googleads.g.doubleclick.net` is the AdMob endpoint for EVERY app, so allowlisting it to serve our own ad silently unblocks in-app ads across the device — you cannot serve AdMob and block AdMob on the same phone with DNS. Monetisation goes back to the subscription seam, which is one function (`entitledToAdBlocking`) and already in place |
| 2026-09-18 | The app is back inside the tunnel, and the exit check with it | Self-exclusion existed only so AdMob could reach a non-datacenter address. With the ads gone its only remaining effect was to break `/whoami` — the API saw the phone's real address, so the connect screen would report a leak on every healthy connection. Reverting restores V1 |

| 2026-09-17 | **The app excludes itself from the tunnel**, always, and the AdMob allowlist is gone | AdMob will not serve a rewarded ad to a request from a cloud exit address — confirmed by testing both ways: the same ad loads with the VPN off and fails with it on, every time, as `LoadAdError code 2`. Since the ad is what buys ad blocking, a tunnel that swallows it makes the feature unusable. Excluding our own package sends its ad traffic out over the phone's own connection, and confines the exemption to this app instead of weakening everybody's filtering: the five AdMob hosts are no longer allowlisted, so `pagead2` and `tpc` web ads are blocked for users again. Our own traffic is API calls and ads, neither of which anyone runs a VPN to hide from us |
| 2026-09-17 | The exit check came off the connect screen, and V1 is reopened | It asked the API what source address our request arrived from — the one claim on that screen a broken tunnel could not fake. With this app outside the tunnel the API always sees the phone's real address, so the card would report a leak on every healthy connection. A false alarm where the user looks for proof is worse than no proof. `ExitCheckCard` and `/whoami` are intact and still tested directly; the honest replacement is server-attested — the node knows the peer's last handshake and byte counters, which a device cannot fake about itself |

| 2026-09-17 | **Neither resolver answers AAAA**, and the unfiltered one moved from Unbound to a second Blocky instance to make that possible | The node has no IPv6 egress — no global v6 address on ens5, `curl -6` fails, forwarding off — while peers route `::/0` into the tunnel so v6 cannot leak around the VPN. Handing out AAAA therefore pointed clients at addresses that silently blackhole: they waited for a reply that could not come and the app reported a network timeout. Google is IPv6-heavy, so this broke AdMob (`LoadAdError code 2, Network error`) while IPv4-only traffic, including our own API by bare IP, was unaffected. Blocky can drop AAAA (`filtering.queryTypes`); Unbound has no global switch for it, so `10.8.0.254` is now a second Blocky with no denylists. Both still forward to the same Unbound, so turning ad blocking off still does not move anyone off the node's own DNS |

| 2026-09-16 | The unfiltered resolver's address must be **assigned to wg0**, not merely freebind-bound | `ip-freebind` lets unbound bind an address that does not exist yet, which is what gets it through boot — but it does not make the address *reachable*. A packet arriving for an address the kernel does not consider local is forwarded, not delivered, so the listener never sees it and unbound cannot even send replies (`udp_send_cb` errors in the journal). Caught in production: `dig @10.8.0.254` returned "no servers could be reached" while `ss` cheerfully showed unbound listening on it. Both scripts now `ip addr add` it and persist it in the `Address =` line of `wg0.conf` |

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-15 | The account tab **no longer shows devices, the device quota, or API health** | An account holds exactly one peer — connecting revokes whatever came before — so a list of one row that cannot be acted on, above a bar reading "1 of 5", describes a product that does not exist yet. API health is an operator's question, not a user's, and `journalctl` answers it better. The screens and the route are parked rather than deleted: the single-device rule is a decision, not an architecture, and `vpn_session.dart` names the line that changes when a phone and a laptop can share an account |
| 2026-09-15 | The tunnel moved out of `TunnelBridge` into a process-scoped **`TunnelHost`** | A Quick Settings tile runs in this process with no activity and no Flutter engine, and has to see the tunnel and take it down. It also fixed something already wrong: the interface outlives the activity, so state scoped to an activity could vanish while the thing it described was still carrying traffic |
| 2026-09-15 | The **kill switch loop moved with it** | Extracting the tunnel alone would have been a regression: the bridge unregisters its listener on dispose, so a kill switch owned by the activity would have stopped rebuilding dropped tunnels the moment that activity was destroyed — exactly when nothing is watching and the feature matters most |
| 2026-09-15 | The tile toggles directly when it can, and **opens the app when it cannot** | Taking a tunnel down needs only the backend. Bringing one up from nothing means reading a private key out of the keystore and possibly registering a peer, neither of which is reachable without Dart. The app is launched with a request already standing, so it connects on arrival rather than showing a button to tap again |
| 2026-09-15 | A connect request from the platform is a **standing flag Dart acknowledges**, not an event | A tile tap happens seconds before a Flutter engine exists. A signal the app had to be listening for at that instant would simply be missed; a flag that waits is served by the first thing to look. It also replaced auto-connect's "watch for the timestamp changing", which had the same race on a cold start |
| 2026-09-15 | The tile sets `userRequestedDown`, like any other deliberate teardown | Otherwise the kill switch would rebuild the tunnel a user had just taken down from the shade, and the tile would look broken in the most visible way possible |
| 2026-09-15 | **Node health is observed and separate from `Node.active`** | `active` is an operator's intent and is set by hand. Nothing was watching whether a node was actually there, so a node that died stayed in selection: every new device issued on it got a config that could not connect. One flag could not carry both meanings, and an automatic process must not write to a column an operator also edits |
| 2026-09-15 | The health probe is the **peer sweep that already runs**, not a second poller | Reading a node's peers means reaching it, so the sweep already answers the question. A separate poller would be two things to keep in step and twice the traffic to an agent that is already being asked |
| 2026-09-15 | Two consecutive failures before a node leaves selection; **one success to return** | A single timeout is the most ordinary thing there is, and treating it as an outage would move users between countries for nothing. Recovery is not symmetrical because a node that answers is answering, and holding it out to be sure would extend an outage that is already over |
| 2026-09-15 | A node nothing has probed counts as **healthy**, and a fleet that all looks dead is **used anyway** | Health is in-memory, so a restart knows nothing until the first sweep; assuming the worst would turn every restart into an outage. And a whole fleet reading as down is far more likely to be a broken probe than every node being dead |
| 2026-09-15 | Failover **re-provisions on the next connect**, only on automatic, and never on a fleet list that failed to load | A peer belongs to one node, so a dead node leaves a device unable to connect and unable to move. A location the user picked is theirs to keep — moving them out of a country they chose is worse than a failure with a reason. And revoking a working peer because `GET /nodes` timed out would be the app causing the outage it was routing around |
| 2026-09-15 | Both protection settings are **armed by the signed-in shell**, not by the account tab | Found while wiring auto-connect, and it was already true of the kill switch: each pushes itself to the platform when its controller first builds, and that build only happened when someone opened Account. A kill switch armed last week was therefore not armed after a restart until the user went and looked at it |
| 2026-09-15 | Split tunnelling **excludes**, never includes | An allow-list would silently drop every app installed after it was written off the tunnel. Excluding names only what the user chose, so the default for anything new is protected |
| 2026-09-15 | The picker lists **launcher-visible apps**, via a `<queries>` intent filter rather than `QUERY_ALL_PACKAGES` | That permission needs a Play Store declaration and grants far more visibility than a picker needs. The cost is that a headless app cannot be excluded, which is the right side to err on — the list stays what a person recognises |
| 2026-09-15 | Excluded packages are **filtered against what is installed** before the config is built | `addDisallowedApplication` throws on a package that is not there, and the throw comes out of `setState` as a failed connect. Without the filter, excluding an app and later uninstalling it would leave the user unable to connect at all |
| 2026-09-15 | Changing exclusions **does not reconnect**; a banner asks | The set is only applied when an interface is built, so a change mid-session does nothing until a rebuild. Dropping someone's tunnel because they ticked a checkbox is a worse surprise than a banner telling them to |
| 2026-09-15 | Auto-connect works **only while Aegis is running**, and the card says so | Android does not let an app start a VPN from a cold start, and the config the platform would re-establish is memory-only by an earlier decision. Pretending otherwise would be the kill-switch lie again: a feature someone believes covers them while the app is gone. Android's always-on VPN is the pointer for that case |
| 2026-09-15 | A Wi-Fi network whose SSID cannot be read counts as **untrusted** | Which is every network until the location permission is granted. Connecting on a network the user trusts wastes a tunnel; not connecting on one they do not is the exposure the feature exists to prevent |
| 2026-09-15 | Auto-connect fires on **arriving at a network**, not on the tunnel being down | Otherwise the user could never disconnect while sitting on an untrusted network — every teardown would be undone by the next capability change, a fight the app always wins and the user always loses |
| 2026-09-15 | The platform brings the tunnel up itself when it holds a config, and **asks Dart** when it does not | A cold process has nothing to re-establish and needs a peer provisioned first, which only Dart can do. The request rides in the status snapshot as a timestamp, and a *change* in it is the signal — so a replayed snapshot cannot fire a second connect |
| 2026-09-15 | Session history is **on-device only**, in the keystore, capped at 50 | A record of when someone used a VPN and how much moved through it is exactly the log this product exists so that nobody else keeps. The cap is because the whole list is serialised on every write |
| 2026-09-15 | Session totals are **accumulated while the tunnel is up**, across interface rebuilds | The platform reports zeroes once the interface is gone, so reading the closing snapshot would file every session as having carried nothing; and WireGuard's counters restart at zero on the rebuilds the kill switch performs routinely, so the last reading alone would report only what moved since the final reconnect |
| 2026-09-15 | The kill switch page became the **Protection** page | Auto-connect answers the other half of the same question — one brings a tunnel back, the other brings one up that was never there — and both have a limit Android imposes that has to be stated next to the toggle |
| 2026-09-15 | **"Automatic" is decided on the client**, which sends an explicit `nodeId`; `selectLeastLoaded()` is now only the fallback | The server cannot know where a client is without geolocating its address, which is the one lookup a VPN should not perform. The client already had to rank the fleet to put a country on the connect screen, so leaving the decision on the server meant the screen predicted one node and the server chose another — and they disagreed precisely when the fleet was busy |
| 2026-09-15 | Nearness is **estimated from the device's UTC offset**, not measured | Neither measurement was available. WireGuard answers no unauthenticated packet, so `:51820` cannot be timed; the only other listener on an exit node is the agent, whose port is security-group-locked to the API and must not be opened to the world to time a round trip. A time zone needs no permission, works offline, and is a real signal of physical position |
| 2026-09-15 | Longitude only, against **country centroids**, in 15° bands with load as the tie-break | East-west distance dominates intercontinental latency, and a time zone gives longitude and nothing else. Mixing in a latitude guessed from the device locale would dress a worse signal up as precision. Within a band the estimate cannot tell two nodes apart, so load decides — which keeps the spreading that automatic did before |
| 2026-09-15 | The button reads **"Closest to you"**, with a caption saying it is estimated and not measured | Renaming was half the fix. "Fastest available" over a rule that never timed anything is the same class of lie as a shield badge over an unverified tunnel |
| 2026-09-15 | An automatic pick that 404s or 503s **retries once with no `nodeId`** | The fleet it was ranked against is cached, so the node can have been deactivated or filled since. A user who asked for automatic should not be told their location is gone. A location they picked themselves does surface the error, because silently moving someone out of the country they chose is worse |
| 2026-09-15 | `Device.lastSeenAt` is written by **polling `wg show dump`**, forward-only | A peer never checks in with the API — it talks to a kernel interface that does not know the API exists — so a poll is the only way this reaches the database. Forward-only because a node rebuilt from its config has no handshake history, and a live device must not be reported as having gone quiet because its interface forgot |
| 2026-09-15 | The sweep treats each node independently and counts failures rather than throwing | One unreachable agent must not cost the rest of the fleet its timestamps |
| 2026-09-15 | `GET /whoami` is `@Public()` | It is called at the two moments an access token is least reliable — just after the interface comes up, and while a refresh is in flight over a route that just changed. Turning "am I protected?" into a 401 is the least useful possible answer, and the endpoint reveals only the caller's own address |
| 2026-09-15 | Tunnelled traffic is recognised by the node's **endpoint IP or its tunnel subnet** | Two different paths reach the API: a client behind a remote node arrives SNATed as that node's public address, while a client on the node the API itself runs on arrives from `10.8.0.x` with no NAT at all. Matching only the first would report a leak for every Mumbai user |
| 2026-09-15 | A node whose egress address differs from its endpoint reads as **not tunnelled** | The false negative is deliberate: it warns a protected user rather than reassuring an exposed one. Fixed by making the node row's endpoint match the address it actually egresses as |
| 2026-09-15 | `/whoami` is left on the **default throttle**, not given a tighter one | Every client connected through a node shares that node's source address, so a strict per-IP limit would let one user's checks lock out everyone else's |
| 2026-09-11 | The kill switch is **client-only; the backend has no part in it** | It is a device-local network policy. No endpoint, table or config would make it work, and syncing the preference across a user's devices is arguably wrong — lockdown on a phone does not imply lockdown on a laptop. An endpoint was not added rather than invent a backend role for a client feature |
| 2026-09-11 | On Android an app **cannot** block traffic while the tunnel is down, so the feature is split in two | Only the system's "Block connections without VPN" does that, and it is deliberately not app-settable. Aegis therefore ships rebuild-on-drop, which it can do, and hands the user to VPN settings for the part it cannot. The screen says which is which — a toggle labelled "kill switch" that silently only reconnects would let someone believe they were covered with the app closed |
| 2026-09-11 | Rebuild-on-drop lives in `TunnelBridge`, not in Dart | The drops worth surviving are the ones where the Dart isolate is not running: app backgrounded, engine suspended, OS reclaiming the interface. A reconnect loop in the UI layer only works while someone is watching it |
| 2026-09-11 | Reconnect is capped at 5 attempts with 1-16s backoff, and the last config is held **in memory only** | A revoked peer or withdrawn consent would otherwise retry until the battery died. Persisting the config would mean writing a WireGuard private key to a second place on disk; the keystore stays its only durable home, at the cost of not surviving process death |
| 2026-09-11 | `GoBackend.setAlwaysOnCallback` is registered | Android can start the VpnService itself once always-on is enabled. Without answering that callback the tunnel would never be established, and a user who had also ticked "block connections" would be left with no network at all — the worst possible outcome of switching on a kill switch |
| 2026-09-11 | The connect screen badge reads "Auto-reconnect", not a shield | It does not block traffic. A shield next to "Not protected" would imply the opposite of what is true |
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

- ~~**The reward is taken on trust.**~~ — moot, B3 removed. Kept for the record: `POST /users/me/ad-block/grant` believes the client
  when it says an ad was watched; nothing proves it. AdMob's server-side verification
  (SSV) callback is the fix. Until then `AD_BLOCK_MAX_BANKED_MS` (1h) is the only thing
  bounding a caller in a loop.
- **AdMob is allowlisted in Blocky, and that leaks some web ads.** The rewarded ad that
  buys filtering has to load *while* filtering is on, or extending a grant is
  impossible. `pagead2.googlesyndication.com` and `tpc.googlesyndication.com` also
  serve web ads, so exempting them lets some through. Unavoidable when a blocker is
  funded by ads; the list is kept as narrow as it can be.
- **Test ad ids are in use.** `AdIds` and the `APPLICATION_ID` meta-data in
  AndroidManifest.xml must be swapped together before release — a real app id with test
  unit ids (or the reverse) is what gets an AdMob account flagged for invalid traffic.
- **Existing accounts lose filtering on deploy.** `adBlockUntil` starts null and null
  means not entitled, which is the point of gating, but it is a behaviour change for
  anyone already filtered.

- ~~**Mumbai hands out `1.1.1.1`**~~ — **closed 2026-09-16.** `nodes.dns` is now `10.8.0.1` and a device issued through the live API comes back with `"dns": "10.8.0.1"`; queried from the tunnel address, `doubleclick.net` -> `0.0.0.0` and `example.com` resolves. New devices on Mumbai get ad blocking. Original finding:
  while deploying B1: Mumbai was built by hand, never by `provision.sh` (no `inet aegis`
  nftables table, plain iptables forwarding, Unbound was never installed). The resolver
  chain is now installed there via the new `ops/install-resolver.sh` and verified —
  79,158 domains, `doubleclick.net` -> `0.0.0.0` — but `nodes.dns` is still `1.1.1.1`,
  so it is inert and no user is pointed at it. Frankfurt is `10.9.0.1` and was not
  touched. Flipping Mumbai's column is the remaining step, and see the next item first.
- **Existing devices will not pick up a `nodes.dns` change.** `dns` is baked into the
  config at issuance and read back from the on-device store
  (`tunnel_controller.dart:38`), so flipping the column only reaches newly issued
  devices. Current users keep whatever they were given until they re-add the device, or
  until the app grows a config-refresh path. Decide which before flipping.
- **`ops/install-resolver.sh` duplicates the Unbound and Blocky config from
  `provision.sh`.** Verified identical at the time of writing, ignoring comments. Two
  copies because both scripts have to stay self-contained — the nodes are deployed by
  copying one file, not by `git pull`. Keep them in sync.
- ~~**B2 is built but not deployed**~~ — **deployed to Mumbai 2026-09-16.** Migration
  applied, API swapped, `dnsUnfiltered` = `10.8.0.254`, verified by round-trip against
  the live API: a new device gets `10.8.0.1`, `PATCH adBlockEnabled=false` then
  `GET /devices/:id/config` returns `10.8.0.254`, and back again. Frankfurt is
  untouched and its `dnsUnfiltered` is still null, so the switch reports itself
  unsupported there, which is correct. **The app still needs rebuilding** for the
  switch to appear. Original steps: `prisma migrate deploy` against
  Supabase, an API deploy, a re-run of `install-resolver.sh` on Mumbai to add the
  unfiltered listener on `10.8.0.254`, then `UPDATE nodes SET "dnsUnfiltered" =
  '10.8.0.254' WHERE region = 'in-mumbai'`. Until that column is set,
  `canToggleAdBlocking` is false and the switch correctly reports itself unsupported.
- **The switch is honest only as far as the resolver is.** A user with Android Private
  DNS set to a provider hostname sees "Block ads and trackers: on" and gets ads,
  because their lookups never reach the node. The nftables fix is still not done, and
  it matters more now that the UI makes a promise.
- ~~**Ad blocking is fleet-wide and always on.**~~ — closed by B2. Original note: B1 puts Blocky on the tunnel address in
  front of Unbound; there is no per-user switch yet. `nodes.dns` is unchanged, so no
  backend or app change was needed — but it also means a user cannot opt out. The toggle
  wants a second resolver address per node (`nodes.dnsBlocking`) plus `Device.adBlock`,
  and a tunnel rebuild on flip, because `DNS =` lives in the WireGuard `[Interface]`.
- **DNS blocking is bypassable, and the obvious holes are still open.** A client with a
  hardcoded `8.8.8.8`, or Android's Private DNS set to a provider hostname, never reaches
  Blocky. The fix is nftables on the node — DNAT tunnel traffic on port 53 to the node's
  own resolver and reject 853 — which is not done. The Firefox DoH canary *is* handled
  (`use-application-dns.net` NXDOMAINs in Unbound).
- **Blocky is a new single point of failure for DNS.** If it does not start, the tunnel
  comes up and resolves nothing. `loading.strategy: fast` means a failed blocklist
  download degrades to unfiltered rather than to dead, and the rollback is in
  docs/SERVER-OPS.md, but nothing alerts on it yet.
- **"Ads blocked" counter does not exist.** Users expect the number. Blocky's Prometheus
  endpoint on `127.0.0.1:4000` has fleet totals, not per-device ones; per-device counts
  mean query logging, which is off deliberately on a privacy VPN. Needs a decision.

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
- ~~No `updateLastSeen`~~ — **closed** by `LastSeenService`, which sweeps every
  active node's peers on `DEVICE_LAST_SEEN_POLL_SECONDS` (default 60) and moves
  `Device.lastSeenAt` forward from the handshake timestamps.
- **Tunnelled clients share one source address at the API.** Everyone exiting
  through Frankfurt reaches the API as `3.71.204.118`, so the per-IP throttler
  counts them as a single caller — the global 120/min is effectively shared by
  that node's whole user base. Not introduced by `/whoami`, but that endpoint is
  the first one a client calls repeatedly, so it will be where this shows up.
  Mumbai users are unaffected while the API runs on the same host (they arrive
  from distinct `10.8.0.x` addresses). The fix is keying the throttler on the
  authenticated user where there is one.
- **Node nearness is country-resolution.** `RegionGeo` carries one longitude per
  country, so two nodes in the same country — or two US nodes on opposite coasts —
  are indistinguishable to the ranking and fall through to load. Add a city table
  when a fleet actually has that shape.
- **Node health only sees the control plane.** The probe reaches a node's agent
  (or runs `wg show` locally), so it detects a box that is down, an agent that is
  not running, or a security group that changed. It does **not** detect a node
  whose agent answers while its data plane is broken — a NAT rule gone, the AWS
  source/destination check re-enabled, upstream transit down. Those still surface
  only through the client's exit check.
- **Health is in-memory and per-process.** A second API instance would keep its
  own view, and a restart re-learns everything within one sweep. Fine for one
  instance; it becomes a shared-state problem at the same moment the throttler
  does.
- **Auto-connect's network callback still unregisters with the activity.** The
  kill switch now survives an activity being destroyed; auto-connect does not.
  It matters less — a tunnel that is up is what keeps the process alive, and
  auto-connect has nothing to do while one is — but the two are inconsistent.
- **The split-tunnel picker has no app icons.** Pulling a bitmap per app across
  the platform channel costs more than the picker is worth, so a letter avatar
  stands in. A lazy per-row `appIcon(package)` call is the fix if it starts to
  matter.
- **Auto-connect does not survive the process being killed.** It registers an
  in-process network callback, so a phone that has been rebooted or had Aegis
  swiped away will not connect on its own. A `PendingIntent`-based callback plus
  a receiver might reach further, but starting a VpnService from the background
  runs into Android 12's foreground-service restrictions and none of it can be
  verified without a device. The card states the limit rather than implying
  coverage that is not there.
- **None of S1, A1 or H1 has run on a device.** The Kotlin compiles and the Dart
  side is covered by unit and widget tests against fakes, but no real
  `PackageManager`, no real Wi-Fi transition and no real excluded-app tunnel has
  been exercised. The permission flow in particular (location, then an SSID read)
  is the part most likely to need a fix on first contact.
- **The handshake sweep needs `WG_NODE_ID`.** It reads peers through
  `WgRunnerRegistry`, which refuses to guess which interface this host owns once a
  second node is active. Without it every sweep logs a warning per node and writes
  nothing.

---

## Deferred (explicitly out of MVP scope)

- iOS Network Extension target (F7 — needs paid org Apple account)
- Payments / RevenueCat, subscription tiers
- Multi-region + separate `node-agent` control plane
- Per-user bandwidth metering and quota enforcement
- ~~Split tunnelling, kill switch, on-demand connect~~ — all three shipped (S1, K1, A1)
