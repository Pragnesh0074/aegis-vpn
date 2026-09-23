import 'dart:async';

import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/history/data/session_history_store.dart';
import 'package:aegis_vpn/features/history/domain/vpn_session_record.dart';
import 'package:aegis_vpn/features/history/presentation/controller/session_recorder.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_config_store.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// The session recorder turns the status stream into history rows.
///
/// Two of its rules are load-bearing and neither is obvious from the screen:
/// counters restart at zero when the kill switch rebuilds an interface, and the
/// platform reports zeroes once the tunnel is gone. Both are ways a session's
/// totals silently come out wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final config = DeviceConfig(
    deviceId: 'd1',
    name: 'Pixel 9',
    platform: 'android',
    createdAt: DateTime.utc(2026, 9, 15),
    tunnelIp: '10.8.0.4/32',
    dns: '10.8.0.1',
    mtu: 1420,
    node: const DeviceNode(
      id: 'n1',
      name: 'Frankfurt #1',
      region: 'de-frankfurt',
    ),
    peer: const PeerConfig(
      publicKey: 'kP1LqYyZ9Xn2vB7cD4eF6gH8jK0mN3pQ5rS7tU9wX1Y=',
      endpoint: '3.71.204.118:51820',
      allowedIps: '0.0.0.0/0, ::/0',
      persistentKeepalive: 25,
    ),
  );

  TunnelStatus up(int rx, int tx) => TunnelStatus(
    state: TunnelState.connected,
    deviceId: 'd1',
    stats: TunnelStats(rxBytes: rx, txBytes: tx, lastHandshake: DateTime.now()),
  );

  /// A container with the recorder running against a stream the test drives.
  ({ProviderContainer container, StreamController<TunnelStatus> status})
  harness() {
    final status = StreamController<TunnelStatus>.broadcast();
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        tunnelStatusStreamProvider.overrideWith((ref) => status.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      status.close();
    });
    // Listened, not read. Riverpod pauses a provider's own subscriptions while
    // nothing is observing it, so a recorder that was merely read would sit
    // there receiving none of the status stream. In the app the signed-in shell
    // watches it, which is the same thing.
    container.listen(sessionRecorderProvider, (_, _) {});
    return (container: container, status: status);
  }

  /// Emits [value] and lets the recorder see it.
  ///
  /// The delay is not decoration. A broadcast stream drops what it emits before
  /// anything is listening, and the recorder's subscription is established a
  /// turn after the provider is first read — so a status added in the same turn
  /// would never arrive and the session would never open.
  Future<void> pump(
    StreamController<TunnelStatus> status,
    TunnelStatus value,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    status.add(value);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  test('records a session with the node it exited through', () async {
    final (:container, :status) = harness();
    await container.read(tunnelConfigStoreProvider).save(config);

    await pump(status, up(0, 0));
    await pump(status, up(4096, 2048));
    await pump(status, TunnelStatus.disconnected);
    // The write is fire-and-forget so the disconnect is not held up by it.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sessions = await container.read(sessionHistoryStoreProvider).read();
    expect(sessions, hasLength(1));
    expect(sessions.single.rxBytes, 4096);
    expect(sessions.single.txBytes, 2048);
    expect(sessions.single.nodeName, 'Frankfurt #1');
    expect(sessions.single.region, 'de-frankfurt');
  });

  test('carries totals across an interface rebuild', () async {
    // What the kill switch does routinely: the tunnel is re-established and
    // WireGuard's counters start again from zero. Taking the last reading alone
    // would report only what moved after the final reconnect.
    final (:container, :status) = harness();

    await pump(status, up(1000, 500));
    await pump(status, up(3000, 1500));
    await pump(status, up(100, 50)); // rebuilt: counters went backwards
    await pump(status, up(700, 350));
    await pump(status, TunnelStatus.disconnected);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sessions = await container.read(sessionHistoryStoreProvider).read();
    expect(sessions.single.rxBytes, 3700, reason: '3000 banked + 700 since');
    expect(sessions.single.txBytes, 1850);
  });

  test('the zeroes reported after teardown do not wipe the totals', () async {
    // The platform stops reporting counters the moment the interface is gone, so
    // a recorder that read the closing snapshot would file every session as
    // having carried nothing.
    final (:container, :status) = harness();

    await pump(status, up(8192, 4096));
    await pump(
      status,
      const TunnelStatus(state: TunnelState.disconnected, deviceId: 'd1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final sessions = await container.read(sessionHistoryStoreProvider).read();
    expect(sessions.single.rxBytes, 8192);
  });

  test(
    'an interface that came up and carried nothing is not recorded',
    () async {
      final (:container, :status) = harness();

      await pump(status, up(0, 0));
      await pump(status, TunnelStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await container.read(sessionHistoryStoreProvider).read(), isEmpty);
    },
  );

  test(
    'a session whose config is gone is still recorded, without a location',
    () async {
      // Re-provisioning replaces the cached config. Dropping the row would lose a
      // real session; inventing a country would be worse than admitting it.
      final (:container, :status) = harness();

      await pump(status, up(1024, 1024));
      await pump(status, TunnelStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sessions = await container.read(sessionHistoryStoreProvider).read();
      expect(sessions.single.nodeName, isNull);
      expect(sessions.single.totalBytes, 2048);
    },
  );

  test('history is newest first and capped', () async {
    final store = SessionHistoryStore(InMemorySecureStore());

    for (var i = 0; i < SessionHistoryStore.limit + 5; i++) {
      await store.add(
        VpnSessionRecordFixture.at(
          DateTime.utc(2026, 9, 15).add(Duration(hours: i)),
        ),
      );
    }

    final sessions = await store.read();
    expect(sessions, hasLength(SessionHistoryStore.limit));
    expect(sessions.first.startedAt.isAfter(sessions.last.startedAt), isTrue);
  });
}

/// A throwaway record, for the store's own behaviour rather than the recorder's.
abstract final class VpnSessionRecordFixture {
  static VpnSessionRecord at(DateTime startedAt) => VpnSessionRecord(
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 5)),
    rxBytes: 1024,
    txBytes: 512,
    nodeName: 'Mumbai #1',
    region: 'in-mumbai',
  );
}
