import 'dart:async';

import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/splittunnel/domain/installed_app.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:aegis_vpn/features/tunnel/presentation/controller/platform_connect_watcher.dart';
import 'package:aegis_vpn/features/tunnel/presentation/controller/vpn_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// The platform can want a tunnel it cannot build: the Quick Settings tile
/// tapped on a cold start, or auto-connect arriving at an untrusted network with
/// no config held. Both leave a standing request for the app to serve.
///
/// The request stands until acknowledged rather than firing once, because a tile
/// tap happens seconds before a Flutter engine exists — an event nobody was
/// listening for is an event that never happened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingChannel channel;
  late StreamController<TunnelStatus> status;
  late _Counter connects;

  ProviderContainer harness() {
    channel = _RecordingChannel();
    status = StreamController<TunnelStatus>.broadcast();
    connects = _Counter();

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        tunnelChannelProvider.overrideWithValue(channel),
        tunnelStatusStreamProvider.overrideWith((ref) => status.stream),
        // A fresh notifier per build: `vpnSession` auto-disposes, and Riverpod
        // rejects the same instance being handed back twice.
        vpnSessionProvider.overrideWith(() => _RecordingSession(connects)),
      ],
    );
    addTearDown(() {
      container.dispose();
      status.close();
    });
    // Listened rather than read: Riverpod pauses a provider's own subscriptions
    // while nothing observes it, and the signed-in shell watches this one.
    container.listen(platformConnectWatcherProvider, (_, _) {});
    return container;
  }

  Future<void> emit({DateTime? requestedAt, bool up = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    status.add(
      TunnelStatus(
        state: up ? TunnelState.connected : TunnelState.disconnected,
        connectRequestedAt: requestedAt,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  test('a standing request is served once and acknowledged', () async {
    harness();

    await emit();
    expect(connects.value, 0, reason: 'nothing was asked for');

    final at = DateTime.utc(2026, 9, 15, 10);
    await emit(requestedAt: at);

    expect(connects.value, 1);
    expect(channel.acks, 1, reason: 'the request has to be spent');
  });

  test('the request is not re-served while it still stands', () async {
    // The status stream repeats itself every second once the tunnel is up, and
    // the platform keeps reporting the request until the acknowledgement lands.
    harness();

    final at = DateTime.utc(2026, 9, 15, 10);
    await emit(requestedAt: at);
    await emit(requestedAt: at, up: true);
    await emit(requestedAt: at, up: true);

    expect(connects.value, 1);
  });

  test('a later request is served in its turn', () async {
    harness();

    await emit(requestedAt: DateTime.utc(2026, 9, 15, 10));
    // Acknowledged, so the platform stops reporting it.
    await emit();
    await emit(requestedAt: DateTime.utc(2026, 9, 15, 11));

    expect(connects.value, 2);
    expect(channel.acks, 2);
  });

  test('a connect that fails is still acknowledged', () async {
    // Otherwise a request that cannot succeed — a revoked peer, a node that is
    // gone — would be retried for as long as the app stayed open.
    harness();
    connects.fail = true;

    await emit(requestedAt: DateTime.utc(2026, 9, 15, 10));

    expect(channel.acks, 1);
  });
}

class _Counter {
  int value = 0;
  bool fail = false;
}

class _RecordingSession extends VpnSession {
  _RecordingSession(this._connects);

  final _Counter _connects;

  @override
  Future<bool> connect() async {
    _connects.value++;
    if (_connects.fail) throw const TunnelException('nope');
    return true;
  }
}

class _RecordingChannel implements TunnelChannel {
  int acks = 0;

  @override
  Future<void> ackConnectRequest() async => acks++;

  @override
  Future<bool> requestAddTile() async => true;

  @override
  Future<void> connect({
    required DeviceConfig config,
    required String privateKey,
    List<String> excludedApps = const [],
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<InstalledApp>> listApps() async => const [];

  @override
  Future<void> setKillSwitch({required bool enabled}) async {}

  @override
  Future<bool> openVpnSettings() async => false;

  @override
  Future<TunnelStatus> status() async => TunnelStatus.disconnected;

  @override
  Stream<TunnelStatus> watch() => const Stream.empty();
}
