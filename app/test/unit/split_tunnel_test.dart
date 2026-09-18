import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/devices/data/device_key_store.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/splittunnel/data/excluded_apps_store.dart';
import 'package:aegis_vpn/features/splittunnel/domain/installed_app.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_config_store.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:aegis_vpn/features/tunnel/presentation/tunnel_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// Split tunnelling is only real if the excluded set survives the trip from the
/// keystore into the interface that gets built. Everything else is a checkbox.
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
    node: DeviceNode(id: 'n1', name: 'Mumbai #1', region: 'in-mumbai'),
    peer: PeerConfig(
      publicKey: 'kP1LqYyZ9Xn2vB7cD4eF6gH8jK0mN3pQ5rS7tU9wX1Y=',
      endpoint: '3.111.32.212:51820',
      allowedIps: '0.0.0.0/0, ::/0',
      persistentKeepalive: 25,
    ),
  );

  test('a selection survives a round trip through the store', () async {
    final store = ExcludedAppsStore(InMemorySecureStore());

    expect(await store.read(), isEmpty);
    await store.write({'com.bank.app'});
    expect(await store.read(), {'com.bank.app'});
  });

  test('the excluded set reaches the platform on connect', () async {
    final channel = _RecordingChannel();
    final secure = InMemorySecureStore();
    stubTunnelChannel();

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(secure),
        tunnelChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);

    // The two local halves a connect needs, plus the choice under test.
    await container.read(tunnelConfigStoreProvider).save(config);
    await container.read(deviceKeyStoreProvider).save('d1', 'a-private-key');
    await container
        .read(excludedAppsStoreProvider)
        .write({'com.bank.app', 'com.chat.app'});

    final ok = await container.read(tunnelControllerProvider.notifier).connect('d1');

    expect(ok, isTrue);
    // Sorted, because the store writes them that way — the order is not
    // meaningful, but a stable one makes this assertion worth making.
    expect(channel.excluded, ['com.bank.app', 'com.chat.app']);
  });

  test('no selection means nothing is excluded', () async {
    final channel = _RecordingChannel();
    stubTunnelChannel();

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        tunnelChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tunnelConfigStoreProvider).save(config);
    await container.read(deviceKeyStoreProvider).save('d1', 'a-private-key');

    await container.read(tunnelControllerProvider.notifier).connect('d1');

    expect(channel.excluded, isEmpty);
  });

  group('InstalledApp.matches', () {
    const app = InstalledApp(
      package: 'com.bank.example',
      label: 'Example Bank',
      isSystem: false,
    );

    test('matches on label and package, case-insensitively', () {
      expect(app.matches(''), isTrue);
      expect(app.matches('bank'), isTrue);
      expect(app.matches('EXAMPLE'), isTrue);
      expect(app.matches('com.bank'), isTrue);
      expect(app.matches('telegram'), isFalse);
    });
  });
}

/// Records what the platform layer was asked to do.
class _RecordingChannel implements TunnelChannel {
  List<String>? excluded;

  @override
  Future<void> connect({
    required DeviceConfig config,
    required String privateKey,
    List<String> excludedApps = const [],
  }) async {
    excluded = excludedApps;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<InstalledApp>> listApps() async => const [];

  @override
  Future<void> ackConnectRequest() async {}

  @override
  Future<bool> requestAddTile() async => false;

  @override
  Future<void> setKillSwitch({required bool enabled}) async {}

  @override
  Future<bool> openVpnSettings() async => false;

  @override
  Future<TunnelStatus> status() async => TunnelStatus.disconnected;

  @override
  Stream<TunnelStatus> watch() => const Stream.empty();
}
