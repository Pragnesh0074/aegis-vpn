import 'package:aegis_vpn/features/devices/data/devices_repository.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:aegis_vpn/features/nodes/presentation/nodes_providers.dart';
import 'package:aegis_vpn/features/nodes/presentation/selected_node.dart';
import 'package:aegis_vpn/features/tunnel/presentation/vpn_session.dart';
import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// An account is allowed exactly one peer.
///
/// Connecting used to issue a fresh one whenever this install could not see the
/// private key of an existing device — which is every install, because app data
/// goes with an uninstall. The peers left behind stayed active, counted against
/// the cap, and sat on the node's interface unable to ever handshake.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingDevices repository;

  ProviderContainer containerWith(List<Device> existing) {
    repository = _RecordingDevices(existing);
    stubTunnelChannel();

    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        devicesRepositoryProvider.overrideWithValue(repository),
        // Automatic, so the node already chosen is never a reason to re-issue.
        // This isolates the policy under test.
        selectedNodeIdProvider.overrideWith(() => _AutomaticNode()),
        // Automatic now ranks the fleet on this side rather than leaving the
        // choice to the backend, so a stubbed list is what keeps this off the
        // network — and `GET /nodes` failing must not be what this test measures.
        vpnNodesProvider.overrideWith((ref) async => _fleet),
        deviceUtcOffsetProvider.overrideWithValue(
          const Duration(hours: 5, minutes: 30),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the first connect issues exactly one peer', () async {
    final container = containerWith([]);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.created, 1);
    expect(repository.revoked, isEmpty);
  });

  test('connecting again reuses the peer rather than issuing another', () async {
    final container = containerWith([]);
    final session = container.read(vpnSessionProvider.notifier);

    await session.connect();
    await session.connect();

    expect(repository.created, 1, reason: 'the second connect must reuse');
    expect(repository.revoked, isEmpty);
  });

  test('a peer this install cannot drive is revoked, not left behind', () async {
    // The shape an uninstall leaves: the account still has the peer, but the
    // private key that made it usable went with the app data.
    final orphan = _device('11111111-1111-4111-8111-111111111111');
    final container = containerWith([orphan]);

    await container.read(vpnSessionProvider.notifier).connect();

    expect(repository.revoked, [orphan.id], reason: 'the stale peer must go');
    expect(repository.created, 1);
    expect(repository.live.length, 1, reason: 'exactly one peer survives');
  });

  test('a revoke the server rejects still lets the connect through', () async {
    final stuck = _device('22222222-2222-4222-8222-222222222222');
    final container = containerWith([stuck]);
    repository.failRevoke = true;

    await container.read(vpnSessionProvider.notifier).connect();

    // Being unable to get online because an unrelated node is down would be a
    // worse failure than a peer left behind on it.
    expect(repository.created, 1);
  });
}

/// One node, so automatic has something to resolve to without a network call.
const _fleet = [
  VpnNode(
    id: 'n1',
    name: 'Mumbai #1',
    region: 'in-mumbai',
    load: 0.1,
    available: true,
  ),
];

Device _device(String id) => Device(
      id: id,
      name: 'Android · aaaa',
      platform: 'android',
      tunnelIp: '10.8.0.2/32',
      createdAt: DateTime.utc(2026),
      lastSeenAt: null,
      node: const DeviceNode(id: 'n1', name: 'Mumbai #1', region: 'in-mumbai'),
    );

class _AutomaticNode extends SelectedNodeId {
  @override
  Future<String?> build() async => null;
}

class _RecordingDevices implements DevicesRepository {
  _RecordingDevices(List<Device> existing) : live = [...existing];

  final List<Device> live;
  final List<String> revoked = [];
  int created = 0;
  bool failRevoke = false;

  @override
  Future<List<Device>> list() async => List.unmodifiable(live);

  @override
  Future<DeviceConfig> create({
    required String publicKey,
    required String name,
    required String platform,
    String? nodeId,
  }) async {
    created++;
    final id = 'created-$created';
    live.add(_device(id));
    return DeviceConfig(
      deviceId: id,
      name: name,
      platform: platform,
      createdAt: DateTime.utc(2026),
      tunnelIp: '10.8.0.9/32',
      dns: '10.8.0.1',
      mtu: 1420,
      node: const DeviceNode(id: 'n1', name: 'Mumbai #1', region: 'in-mumbai'),
      peer: const PeerConfig(
        publicKey: 'gsw8npeFnaTO+019dLZNo7ra6jVitQWEialU6kjwtDk=',
        endpoint: '3.111.32.212:51820',
        allowedIps: '0.0.0.0/0, ::/0',
        persistentKeepalive: 25,
      ),
    );
  }

  @override
  Future<void> revoke(String deviceId) async {
    if (failRevoke) throw Exception('node unreachable');
    revoked.add(deviceId);
    live.removeWhere((device) => device.id == deviceId);
  }
}
