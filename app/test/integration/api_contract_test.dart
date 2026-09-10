@Tags(['live'])
library;

import 'package:aegis_vpn/core/network/api_client.dart';
import 'package:aegis_vpn/core/network/auth_interceptor.dart';
import 'package:aegis_vpn/core/session/auth_tokens.dart';
import 'package:aegis_vpn/core/session/session_store.dart';
import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/auth/data/auth_repository.dart';
import 'package:aegis_vpn/features/devices/data/devices_repository.dart';
import 'package:aegis_vpn/features/devices/data/wireguard_keygen.dart';
import 'package:aegis_vpn/features/health/data/health_repository.dart';
import 'package:aegis_vpn/features/nodes/data/nodes_repository.dart';
import 'package:aegis_vpn/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives every repository against a real backend, to prove the models match
/// what the API actually returns rather than what the DTOs suggest it returns.
///
/// Requires the API on `localhost:3000`:
///
///     cd backend && npm run start:dev
///     cd app && flutter test test/integration --tags live --run-skipped
///
/// Excluded from the default `flutter test` run by the `live` tag in
/// `dart_test.yaml`, so the normal suite stays hermetic.
///
/// One constraint shapes this file: `/auth/register` and `/auth/login` are
/// throttled to 5 calls per minute per IP. Accounts are therefore created once in
/// `setUpAll` and handed out, rather than minted per test. Re-running the whole
/// file within a minute can still trip the limiter.
void main() {
  const baseUrl = 'http://localhost:3000';
  const password = 'a-long-enough-password';

  late Dio rawDio;
  late Dio authedDio;
  late SessionStore session;

  /// One throwaway account per test that needs an independent session.
  late Map<String, AuthTokens> accounts;

  String freshEmail(String label) =>
      'contract-$label-${DateTime.now().microsecondsSinceEpoch}@example.test';

  BaseOptions options() => BaseOptions(
        baseUrl: baseUrl,
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 400,
      );

  setUpAll(() async {
    final api = ApiClient(Dio(options()));
    final auth = AuthRepository(api);

    accounts = {};
    // Four registrations, under the 5-per-minute cap.
    for (final label in ['flow', 'badkey', 'refresh', 'concurrent']) {
      final email = freshEmail(label);
      accounts[email] = await auth.register(email: email, password: password);
    }
  });

  setUp(() {
    rawDio = Dio(options());
    session = SessionStore(_InMemorySecureStore());

    // The real interceptor, so token attachment and refresh are exercised too.
    authedDio = Dio(options())
      ..interceptors.add(
        AuthInterceptor(
          store: session,
          refreshClient: rawDio,
          onSessionExpired: () async {},
        ),
      );
  });

  ApiClient publicApi() => ApiClient(rawDio);
  ApiClient authedApi() => ApiClient(authedDio);

  /// Signs the test's client in as the account registered for [label].
  Future<MapEntry<String, AuthTokens>> useAccount(String label) async {
    final entry = accounts.entries.firstWhere((e) => e.key.contains('-$label-'));
    await session.write(entry.value);
    return entry;
  }

  test('health reports the API and its database', () async {
    final health = await HealthRepository(publicApi()).check();
    expect(health.status, anyOf('ok', 'degraded'));
    expect(health.database, 'up', reason: 'the API cannot reach its database');
    expect(health.uptimeSeconds, greaterThanOrEqualTo(0));
  });

  test('full flow: profile, nodes, device issue, list, revoke', () async {
    final account = await useAccount('flow');

    // ── profile ───────────────────────────────────────────────────────────────
    final profile = await ProfileRepository(authedApi()).fetch();
    expect(profile.email, account.key);
    expect(profile.deviceCount, 0);
    expect(profile.maxDevices, greaterThan(0));

    // ── nodes ─────────────────────────────────────────────────────────────────
    final nodes = await NodesRepository(authedApi()).list();
    expect(nodes, isNotEmpty, reason: 'seed at least one node to run this test');
    for (final node in nodes) {
      expect(node.load, inInclusiveRange(0, 1));
    }

    // ── issue a peer ──────────────────────────────────────────────────────────
    final devices = DevicesRepository(authedApi());
    final keys = await const WireguardKeygen().generate();

    final config = await devices.create(
      publicKey: keys.publicKey,
      name: 'Contract Test',
      platform: 'android',
      nodeId: nodes.first.id,
    );

    expect(config.node.id, nodes.first.id);
    expect(config.tunnelIp, endsWith('/32'));
    expect(config.peer.allowedIps, '0.0.0.0/0, ::/0');
    expect(config.peer.persistentKeepalive, 25);
    expect(config.peer.publicKey, matches(r'^[A-Za-z0-9+/]{43}=$'));
    expect(config.peer.endpoint, contains(':'));
    expect(config.mtu, greaterThan(0));

    // The rendered config must carry the private key that never left this
    // process, and the server's public key — and they must be different keys.
    final wgQuick = config.toWgQuick(privateKey: keys.privateKey);
    expect(wgQuick, contains('PrivateKey = ${keys.privateKey}'));
    expect(wgQuick, contains('PublicKey = ${config.peer.publicKey}'));
    expect(keys.privateKey, isNot(config.peer.publicKey));

    // ── list reflects the new peer ────────────────────────────────────────────
    final list = await devices.list();
    final issued = list.firstWhere((d) => d.id == config.deviceId);
    expect(issued.name, 'Contract Test');
    expect(issued.tunnelIp, config.tunnelIp);
    expect(issued.lastSeenAt, isNull, reason: 'never handshaked');

    expect((await ProfileRepository(authedApi()).fetch()).deviceCount, 1);

    // ── revoke ────────────────────────────────────────────────────────────────
    await devices.revoke(config.deviceId);
    expect(await devices.list(), isEmpty);
    expect((await ProfileRepository(authedApi()).fetch()).deviceCount, 0);

    // Revoking twice succeeds: the backend soft-deletes and returns early on an
    // already-revoked row, so retrying after a dropped response is safe.
    await devices.revoke(config.deviceId);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a malformed public key is rejected with the backend message', () async {
    await useAccount('badkey');

    // Not 43 base64 chars plus '=' — `WG_PUBLIC_KEY` rejects it at the edge.
    await expectLater(
      DevicesRepository(authedApi()).create(
        publicKey: 'not-a-wireguard-key',
        name: 'Bad Key',
        platform: 'android',
      ),
      throwsA(
        isA<Exception>().having((e) => e.toString(), 'message', contains('publicKey')),
      ),
    );
  });

  test('an expired access token is refreshed before the request goes out', () async {
    final account = await useAccount('refresh');

    // Backdate the expiry so the interceptor treats the access token as stale.
    // The refresh token is still genuinely valid — exactly the state a client
    // wakes up in after being backgrounded past the access TTL.
    await session.write(
      AuthTokens(
        accessToken: account.value.accessToken,
        refreshToken: account.value.refreshToken,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      ),
    );

    // Succeeds only if the interceptor rotated the pair first.
    expect((await ProfileRepository(authedApi()).fetch()).email, account.key);

    final rotated = await session.read();
    expect(rotated!.isExpired, isFalse, reason: 'a fresh access token was stored');
    expect(
      rotated.refreshToken,
      isNot(account.value.refreshToken),
      reason: 'the backend rotates the refresh token on every use',
    );
  });

  test('concurrent requests on an expired token share one refresh', () async {
    final account = await useAccount('concurrent');

    await session.write(
      AuthTokens(
        accessToken: account.value.accessToken,
        refreshToken: account.value.refreshToken,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      ),
    );

    // Three at once. Without single-flight, two would present an already-rotated
    // refresh token, which the backend treats as theft and answers by revoking
    // the whole family — so all three must succeed.
    final api = authedApi();
    final results = await Future.wait([
      ProfileRepository(api).fetch(),
      ProfileRepository(api).fetch(),
      ProfileRepository(api).fetch(),
    ]);

    expect(results.map((p) => p.email), everyElement(account.key));
    expect((await session.read())!.isExpired, isFalse);
  });

  test('login is case-insensitive and rejects a wrong password', () async {
    final account = accounts.entries.first;
    final auth = AuthRepository(publicApi());

    await expectLater(
      auth.login(email: account.key, password: 'wrong-password-entirely'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid email or password'),
        ),
      ),
    );

    // The backend lowercases on both register and login, so a shouted address
    // must reach the same account.
    final upper = await auth.login(email: account.key.toUpperCase(), password: password);
    expect(upper.accessToken, isNotEmpty);

    // And logout revokes that pair server-side.
    await auth.logout(upper.refreshToken);
  });
}

/// Stands in for the platform keystore, which has no implementation in a test VM.
class _InMemorySecureStore implements SecureStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
