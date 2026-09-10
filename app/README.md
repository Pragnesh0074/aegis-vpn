# Aegis VPN — Flutter client

The mobile client for the Aegis VPN backend. Every endpoint the API exposes is
integrated here.

| | |
|---|---|
| **State** | Riverpod 3 (`riverpod_generator`) |
| **Routing** | go_router, with auth gating in a single `redirect` |
| **HTTP** | Dio, one interceptor for bearer tokens and refresh |
| **Secrets** | `flutter_secure_storage` (Keychain / Android Keystore) |
| **Crypto** | `cryptography` — X25519, on-device |
| **Sizing** | `flutter_screenutil`, design size 375x812 |

## The security invariant

The device's WireGuard **private key is generated on the phone and never sent
anywhere**. `POST /devices` uploads only the public half. The private key is
written to the platform keystore under the device id the API returns, and is
destroyed when that device is revoked.

Because of that, the full peer config is shown **once** — `GET /devices` omits the
node's public key and endpoint by design, so it cannot be rebuilt later.

## Layout

```
lib/
├── app.dart                 # ScreenUtilInit + MaterialApp.router
├── core/
│   ├── config/              # --dart-define values
│   ├── error/               # sealed AppException hierarchy
│   ├── network/             # Dio, ApiClient, AuthInterceptor, endpoints
│   ├── router/              # routes + session-gated redirect
│   ├── session/             # tokens, keystore-backed store, session state
│   ├── storage/             # the one wrapper over secure storage
│   ├── theme/               # Material 3 + the Gap spacing scale
│   ├── utils/               # validators mirroring the backend DTOs, formatters
│   └── widgets/             # AsyncView, DetailRow, error text
└── features/<module>/
    ├── domain/              # models mirroring the API response shapes
    ├── data/                # repository — the only place a route is called
    └── presentation/        # providers, controllers, screens
```

Each feature is self-contained; `core` never imports a feature.

## Modules and the endpoints they own

| Module | Endpoints | Screens |
|---|---|---|
| `auth` | `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout` | Sign in, Create account |
| `profile` | `GET /users/me` | Account |
| `nodes` | `GET /nodes` | Servers |
| `devices` | `GET /devices`, `POST /devices`, `DELETE /devices/:id` | Devices, Add device, Device config |
| `health` | `GET /health` | Status card on Account |
| `home` | — | Bottom-nav shell |

## Running

The API has no global route prefix, so `API_BASE_URL` is the bare origin.

```bash
# Android emulator (default — 10.0.2.2 is the emulator's route to your machine)
flutter run

# a device on the same network
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

## Code generation

Riverpod providers are generated. After editing anything annotated `@riverpod`:

```bash
dart run build_runner build     # or: watch
```

## Tests

```bash
flutter test                    # unit + widget; hermetic
```

The widget tests render every offline screen at 320x640 and 430x932 and fail on an
overflow, which is what keeps the ScreenUtil sizing honest.

There is also a contract suite that drives every repository against a **real**
backend, to catch a response shape drifting from these models:

```bash
cd ../backend && npm run start:dev
flutter test test/integration --tags live --run-skipped
```

It registers throwaway accounts. `/auth/register` and `/auth/login` are throttled
to 5/min per IP, so re-running it immediately can trip the limiter.

## The tunnel

**Android only, for now.** `TunnelBridge.kt` drives WireGuard's own
`com.wireguard.android:tunnel` backend, which owns the `VpnService` and the tun
file descriptor; the protocol is never reimplemented here. Dart talks to it over
a MethodChannel for commands and an EventChannel for state, so a tunnel the OS
takes down on its own still reaches the UI.

**iOS is not implemented.** `ios/` is the stock Flutter scaffold — no Network
Extension target, no entitlements. It needs a paid organization Apple account,
so it is deliberately last. The Dart layer is platform-agnostic already: adding
iOS means answering the same two channels from a `NEPacketTunnelProvider`, with
no change above `TunnelChannel`.
