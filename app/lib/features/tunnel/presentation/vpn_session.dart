import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../devices/data/device_key_store.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/data/wireguard_keygen.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../nodes/presentation/nodes_providers.dart';
import '../../nodes/presentation/selected_node.dart';
import '../../profile/presentation/profile_providers.dart';
import '../data/tunnel_channel.dart';
import '../data/tunnel_config_store.dart';
import 'tunnel_controller.dart';

part 'vpn_session.g.dart';

/// The device this phone can actually drive, or null if there is not one yet.
///
/// "Provisioned" means all three halves are present: the peer exists server-side
/// in `GET /devices`, its cached config is here, and its private key is in the
/// keystore. A device missing either local half appears in the account but
/// cannot be connected from this phone and is not a candidate — the private key
/// was never uploaded and the peer details are not re-issuable, so there is no
/// recovery, only re-provisioning.
@riverpod
Future<Device?> provisionedDevice(Ref ref) async {
  final devices = await ref.watch(devicesProvider.future);
  if (devices.isEmpty) return null;

  final configStore = ref.watch(tunnelConfigStoreProvider);
  final keyStore = ref.watch(deviceKeyStoreProvider);

  Future<bool> isUsable(Device device) async {
    final config = await configStore.read(device.id);
    if (config == null) return false;
    return await keyStore.read(device.id) != null;
  }

  // The one last connected wins, so re-opening the app does not silently move
  // the user to a different peer than the one they were using.
  final preferredId = await configStore.readSelectedDeviceId();
  if (preferredId != null) {
    for (final device in devices) {
      if (device.id == preferredId && await isUsable(device)) return device;
    }
  }

  // Otherwise the newest usable one. `GET /devices` is oldest-first, and a
  // re-provision appends, so the newest is the one this phone just made.
  for (final device in devices.reversed) {
    if (await isUsable(device)) return device;
  }
  return null;
}

/// Connect, disconnect, and switch location — the whole of what the connect
/// screen can do.
///
/// This exists because the app no longer has an "add device" step. A person
/// taps one button and expects to be protected; issuing a WireGuard peer is
/// plumbing they should never have to know about. So this notifier provisions
/// on demand: on the first connect it generates a keypair, registers the public
/// half, caches the peer details, and only then brings the interface up.
///
/// Its own state is the progress of the *provisioning*, which is the slow and
/// failure-prone part. Whether the tunnel is up comes from
/// [tunnelStatusStreamProvider] as it always did, because the platform can take
/// the interface down without asking.
@riverpod
class VpnSession extends _$VpnSession {
  @override
  FutureOr<void> build() {}

  /// Brings up the tunnel, provisioning a peer first if this phone has none.
  Future<bool> connect() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final prepared = await AsyncValue.guard(_ensureDevice);
    if (prepared.hasError) {
      logFailure('provisioning a peer', prepared.error!, prepared.stackTrace!);
      state = AsyncError(prepared.error!, prepared.stackTrace!);
      return false;
    }
    state = const AsyncData(null);

    return ref.read(tunnelControllerProvider.notifier).connect(prepared.value!);
  }

  Future<bool> disconnect() {
    return ref.read(tunnelControllerProvider.notifier).disconnect();
  }

  /// What the connect button does, decided from what the tunnel is actually
  /// doing rather than from what the UI last drew.
  Future<bool> toggle() {
    final status = ref.read(tunnelStatusStreamProvider).value;
    final isUp = status != null && status.state.isUp;
    return isUp ? disconnect() : connect();
  }

  /// Points future connections at [nodeId] — null for automatic.
  ///
  /// A peer belongs to exactly one node, so changing location is not a setting
  /// but a re-issue: the old peer is revoked and a new one is issued on the
  /// chosen node. That is done lazily, on the next connect, unless the tunnel is
  /// up right now — in which case the user asked to move, and waiting would
  /// leave them looking at a country they are not in.
  Future<bool> selectLocation(String? nodeId) async {
    final current = await ref.read(selectedNodeIdProvider.future);
    await ref.read(selectedNodeIdProvider.notifier).select(nodeId);
    if (current == nodeId) return true;

    final status = ref.read(tunnelStatusStreamProvider).value;
    if (status == null || !status.state.isUp) return true;

    if (!await disconnect()) return false;
    return connect();
  }

  /// Returns the device id to connect, provisioning or re-provisioning as needed.
  Future<String> _ensureDevice() async {
    final wantedNodeId = await ref.read(selectedNodeIdProvider.future);
    final existing = await ref.read(provisionedDeviceProvider.future);

    if (existing != null) {
      // Automatic keeps whatever node the backend already chose. Re-issuing on
      // every connect just to re-run the load check would churn peers and burn
      // the device cap for no gain.
      if (wantedNodeId == null || existing.node.id == wantedNodeId) {
        return existing.id;
      }
      await _release(existing.id);
    }

    return _provision(wantedNodeId);
  }

  /// Generates a keypair and registers it, mirroring the order the old
  /// add-device flow used: the peer is revoked again if the local halves cannot
  /// be stored, because a peer with no private key on any device can never
  /// connect and still counts against the cap.
  Future<String> _provision(String? nodeId) async {
    final keys = await ref.read(wireguardKeygenProvider).generate();
    final platform = ref.read(currentPlatformProvider);

    final config = await ref.read(devicesRepositoryProvider).create(
          publicKey: keys.publicKey,
          name: _autoName(platform, keys.publicKey),
          platform: platform.wireValue,
          nodeId: nodeId,
        );

    try {
      await ref.read(deviceKeyStoreProvider).save(config.deviceId, keys.privateKey);
      // `POST /devices` is the only call that returns the node's public key and
      // endpoint, so this cache is the difference between a tunnel that can be
      // restarted and one that can never be built again.
      await ref.read(tunnelConfigStoreProvider).save(config);
    } catch (_) {
      await ref
          .read(devicesRepositoryProvider)
          .revoke(config.deviceId)
          .catchError((_) {});
      rethrow;
    }

    _refresh();
    return config.deviceId;
  }

  /// Revokes a peer server-side and destroys its local halves.
  ///
  /// Revoke first: while the server call is unconfirmed the device is still
  /// connectable, and destroying the key first would strand a working tunnel
  /// with no way to rebuild its config.
  Future<void> _release(String deviceId) async {
    await ref.read(devicesRepositoryProvider).revoke(deviceId);
    await ref.read(deviceKeyStoreProvider).delete(deviceId);
    await ref.read(tunnelConfigStoreProvider).delete(deviceId);
    _refresh();
  }

  /// The device list, the quota on the account screen, and the per-node load all
  /// change when a peer is issued or revoked.
  void _refresh() {
    ref
      ..invalidate(devicesProvider)
      ..invalidate(userProfileProvider)
      ..invalidate(vpnNodesProvider)
      ..invalidate(provisionedDeviceProvider);
  }

  /// A name for a device the user never named.
  ///
  /// The account screen still lists devices, and "Android device" three times
  /// over is useless there, so a short fingerprint of the public key is appended
  /// to tell them apart. The key is public — this leaks nothing.
  static String _autoName(DevicePlatform platform, String publicKey) {
    final fingerprint = publicKey.substring(0, 4);
    return '${platform.label} · $fingerprint';
  }
}
