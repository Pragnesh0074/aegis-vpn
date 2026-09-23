import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:aegis_vpn/features/devices/data/devices_repository.dart';
import 'package:aegis_vpn/features/devices/data/device_key_store.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/nodes/domain/node_ranking.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_location.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:aegis_vpn/features/nodes/presentation/controller/nodes_providers.dart';
import 'package:aegis_vpn/features/nodes/presentation/controller/selected_node.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_config_store.dart';
import 'package:aegis_vpn/features/tunnel/presentation/controller/vpn_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// A peer belongs to exactly one node, so a node that falls over leaves every
/// device on it unable to connect *and* unable to move. The config it holds is
/// still perfectly valid, so nothing about it looks wrong — the app would go on
/// rebuilding a tunnel to a box that is not answering.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VpnNode node(String id, {bool healthy = true, double load = 0.1}) => VpnNode(
    id: id,
    name: id,
    region: id == 'frankfurt' ? 'de-frankfurt' : 'in-mumbai',
    load: load,
    available: healthy,
    healthy: healthy,
  );

  Device device(String nodeId) => Device(
    id: 'd1',
    name: 'Pixel 9',
    platform: 'android',
    tunnelIp: '10.8.0.2/32',
    createdAt: DateTime.utc(2026),
    lastSeenAt: null,
    node: DeviceNode(id: nodeId, name: nodeId, region: 'in-mumbai'),
  );

  late _RecordingDevices repository;

  ProviderContainer harness({
    required List<Device> existing,
    required List<VpnNode> fleet,
    bool fleetFails = false,
  }) {
    repository = _RecordingDevices(existing);
    stubTunnelChannel();

    final container = ProviderContainer(
      // Riverpod retries a provider that threw, with a backoff. That is the
      // right behaviour in the app and pure delay in a test that is *about* the
      // failure, so the retry is turned off rather than waited out.
      retry: (_, _) => null,
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        devicesRepositoryProvider.overrideWithValue(repository),
        selectedNodeIdProvider.overrideWith(_Automatic.new),
        deviceUtcOffsetProvider.overrideWithValue(
          const Duration(hours: 5, minutes: 30),
        ),
        vpnNodesProvider.overrideWith((ref) async {
          if (fleetFails) throw Exception('GET /nodes is down');
          return fleet;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Makes [existing] look like a peer this install can actually drive, which is
  /// what stops `provisionedDevice` treating it as an orphan to be replaced.
  Future<void> seedLocalHalves(
    ProviderContainer container,
    Device device,
  ) async {
    await container
        .read(deviceKeyStoreProvider)
        .save(device.id, 'a-private-key');
    await container
        .read(tunnelConfigStoreProvider)
        .save(
          DeviceConfig(
            deviceId: device.id,
            name: device.name,
            platform: device.platform,
            createdAt: device.createdAt,
            tunnelIp: device.tunnelIp,
            dns: '10.8.0.1',
            mtu: 1420,
            node: device.node,
            peer: const PeerConfig(
              publicKey: 'kP1LqYyZ9Xn2vB7cD4eF6gH8jK0mN3pQ5rS7tU9wX1Y=',
              endpoint: '3.111.32.212:51820',
              allowedIps: '0.0.0.0/0, ::/0',
              persistentKeepalive: 25,
            ),
          ),
        );
  }

  test('a device on a healthy node is left alone', () async {
    final existing = device('mumbai');
    final container = harness(existing: [existing], fleet: [node('mumbai')]);
    await seedLocalHalves(container, existing);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.created, 0, reason: 'nothing was wrong with it');
    expect(repository.revoked, isEmpty);
  });

  test('a device on a node that stopped answering is moved', () async {
    final existing = device('mumbai');
    final container = harness(
      existing: [existing],
      fleet: [node('mumbai', healthy: false), node('frankfurt')],
    );
    await seedLocalHalves(container, existing);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.revoked, [existing.id]);
    expect(repository.created, 1);
    expect(repository.lastNodeId, 'frankfurt', reason: 'the only node left');
  });

  test('a device on a node that has left the fleet is moved', () async {
    final existing = device('retired');
    final container = harness(existing: [existing], fleet: [node('mumbai')]);
    await seedLocalHalves(container, existing);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.created, 1);
    expect(repository.lastNodeId, 'mumbai');
  });

  test('a fleet list that will not load is not treated as an outage', () async {
    // Revoking a working peer because `GET /nodes` timed out would be the app
    // causing the very outage it was trying to route around.
    final existing = device('mumbai');
    final container = harness(
      existing: [existing],
      fleet: const [],
      fleetFails: true,
    );
    await seedLocalHalves(container, existing);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.created, 0);
    expect(repository.revoked, isEmpty);
  });

  group('the fleet view', () {
    test('an unreachable node is never what automatic picks', () {
      final ranked = NodeRanking.nearest([
        node('mumbai', healthy: false),
        node('frankfurt'),
      ], utcOffset: const Duration(hours: 5, minutes: 30));

      // Mumbai is nearer and would win on geography alone.
      expect(ranked?.id, 'frankfurt');
    });

    test('a country reads as offline rather than full', () {
      final [location] = VpnLocation.group([node('mumbai', healthy: false)]);

      expect(location.available, isFalse);
      expect(location.healthy, isFalse);
    });
  });
}

class _Automatic extends SelectedNodeId {
  @override
  Future<String?> build() async => null;
}

class _RecordingDevices implements DevicesRepository {
  _RecordingDevices(List<Device> existing) : live = [...existing];

  final List<Device> live;
  final List<String> revoked = [];
  int created = 0;
  String? lastNodeId;

  @override
  Future<List<Device>> list() async => List.unmodifiable(live);
  // The resolver never moves in these tests, so re-reading a config is a fetch the
  // production code may make but nothing here asserts on.
  @override
  Future<DeviceConfig> fetchConfig(String deviceId) async {
    throw UnimplementedError('fetchConfig is not exercised by this test');
  }

  @override
  Future<DeviceConfig> create({
    required String publicKey,
    required String name,
    required String platform,
    String? nodeId,
  }) async {
    created++;
    lastNodeId = nodeId;
    final id = 'created-$created';
    final node = DeviceNode(
      id: nodeId ?? 'n1',
      name: nodeId ?? 'n1',
      region: 'in-mumbai',
    );
    live.add(
      Device(
        id: id,
        name: name,
        platform: platform,
        tunnelIp: '10.8.0.9/32',
        createdAt: DateTime.utc(2026),
        lastSeenAt: null,
        node: node,
      ),
    );
    return DeviceConfig(
      deviceId: id,
      name: name,
      platform: platform,
      createdAt: DateTime.utc(2026),
      tunnelIp: '10.8.0.9/32',
      dns: '10.8.0.1',
      mtu: 1420,
      node: node,
      peer: const PeerConfig(
        publicKey: 'kP1LqYyZ9Xn2vB7cD4eF6gH8jK0mN3pQ5rS7tU9wX1Y=',
        endpoint: '3.111.32.212:51820',
        allowedIps: '0.0.0.0/0, ::/0',
        persistentKeepalive: 25,
      ),
    );
  }

  @override
  Future<void> revoke(String deviceId) async {
    revoked.add(deviceId);
    live.removeWhere((device) => device.id == deviceId);
  }
}
