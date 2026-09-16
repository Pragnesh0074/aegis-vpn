import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/autoconnect/data/auto_connect_store.dart';
import 'package:aegis_vpn/features/autoconnect/domain/auto_connect_settings.dart';
import 'package:aegis_vpn/features/autoconnect/domain/wifi_network.dart';
import 'package:aegis_vpn/features/autoconnect/presentation/auto_connect_controller.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/splittunnel/domain/installed_app.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// Auto-connect is two halves that have to agree: a preference that survives a
/// restart, and a platform watch that does not. The failure worth testing for is
/// the silent one — a stored `true` the platform never heard about.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a setting survives a round trip through the store', () async {
    final store = AutoConnectStore(InMemorySecureStore());

    expect((await store.read()).enabled, isFalse);

    await store.write(
      const AutoConnectSettings(enabled: true, trusted: ['Home', 'Office']),
    );

    final read = await store.read();
    expect(read.enabled, isTrue);
    expect(read.trusted, ['Home', 'Office']);
  });

  test('a trusted network is matched regardless of case', () {
    const settings = AutoConnectSettings(enabled: true, trusted: ['Home WiFi']);

    expect(settings.trusts('home wifi'), isTrue);
    expect(settings.trusts('Home WiFi'), isTrue);
    expect(settings.trusts('Cafe'), isFalse);
  });

  test('enabling arms the platform, not just the preference', () async {
    final channel = _RecordingChannel();
    final container = _container(channel);

    await container.read(autoConnectProvider.future);
    await container.read(autoConnectProvider.notifier).setEnabled(enabled: true);

    expect(channel.enabled, isTrue);
    // And it is persisted, so the next launch re-arms it.
    expect((await container.read(autoConnectStoreProvider).read()).enabled, isTrue);
  });

  test('a platform that refuses leaves the setting where it was', () async {
    // A toggle showing "on" over a platform that is not watching is exactly the
    // silent no-protection case this feature must not have.
    final channel = _RecordingChannel()..failSetAutoConnect = true;
    final container = _container(channel);

    await container.read(autoConnectProvider.future);

    await expectLater(
      container.read(autoConnectProvider.notifier).setEnabled(enabled: true),
      throwsA(isA<TunnelException>()),
    );
    expect(container.read(autoConnectProvider).value?.enabled, isFalse);
    expect((await container.read(autoConnectStoreProvider).read()).enabled, isFalse);
  });

  test('trusting a network takes its name from the platform', () async {
    final channel = _RecordingChannel()..ssid = 'Home WiFi';
    final container = _container(channel);

    await container.read(autoConnectProvider.future);
    await container.read(autoConnectProvider.notifier).setEnabled(enabled: true);

    final added = await container.read(autoConnectProvider.notifier).trustCurrentNetwork();

    expect(added, 'Home WiFi');
    expect(channel.trusted, ['Home WiFi']);
  });

  test('a network Android will not name cannot be trusted', () async {
    // Which is every network until the location permission is granted. Saying so
    // beats adding an empty entry that matches nothing.
    final channel = _RecordingChannel();
    final container = _container(channel);

    await container.read(autoConnectProvider.future);

    expect(
      await container.read(autoConnectProvider.notifier).trustCurrentNetwork(),
      isNull,
    );
    expect(channel.trusted, isEmpty);
  });
}

ProviderContainer _container(TunnelChannel channel) {
  final container = ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      tunnelChannelProvider.overrideWithValue(channel),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _RecordingChannel implements TunnelChannel {
  bool? enabled;
  List<String> trusted = const [];
  String? ssid;
  bool failSetAutoConnect = false;

  @override
  Future<void> setAutoConnect({
    required bool enabled,
    required List<String> trusted,
  }) async {
    if (failSetAutoConnect) {
      throw const TunnelException('The platform refused.');
    }
    this.enabled = enabled;
    this.trusted = trusted;
  }

  @override
  Future<WifiNetwork> currentWifi() async =>
      WifiNetwork(ssid: ssid, hasPermission: ssid != null);

  @override
  Future<bool> requestWifiPermission() async => false;

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
