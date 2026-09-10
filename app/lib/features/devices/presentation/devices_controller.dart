import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../nodes/presentation/nodes_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/data/tunnel_config_store.dart';
import '../data/device_key_store.dart';
import '../data/devices_repository.dart';
import '../data/wireguard_keygen.dart';
import '../domain/device_config.dart';
import 'devices_providers.dart';

part 'devices_controller.g.dart';

/// Mutations on the device list: issuing a peer and revoking one.
///
/// Reads stay in [devicesProvider]. Keeping them apart means a failed mutation
/// shows an error without blanking the list the user is looking at.
@riverpod
class DevicesController extends _$DevicesController {
  @override
  FutureOr<void> build() {}

  /// Generates a keypair, registers the public half, and stores the private half.
  ///
  /// Returns the issued config so the caller can show it once — the node's public
  /// key and endpoint are not returned by `GET /devices` and cannot be fetched again.
  Future<DeviceConfig?> addDevice({
    required String name,
    required String platform,
    String? nodeId,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      final keys = await ref.read(wireguardKeygenProvider).generate();

      final config = await ref.read(devicesRepositoryProvider).create(
            publicKey: keys.publicKey,
            name: name.trim(),
            platform: platform,
            nodeId: nodeId,
          );

      // The peer exists server-side but is useless without its private key. If
      // the keystore write fails, revoke rather than leave a peer that can never
      // connect and still counts against the device cap.
      try {
        await ref.read(deviceKeyStoreProvider).save(config.deviceId, keys.privateKey);
        // The peer details come back from this one call and never again, so cache
        // them now or the tunnel can never be started after this screen closes.
        await ref.read(tunnelConfigStoreProvider).save(config);
      } catch (_) {
        await ref
            .read(devicesRepositoryProvider)
            .revoke(config.deviceId)
            .catchError((_) {});
        rethrow;
      }

      _refreshAfterMutation();
      return config;
    });

    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    return result.value;
  }

  /// Revokes the peer, then destroys the local private key.
  ///
  /// That order is deliberate. If the server call fails the key is kept, because
  /// the device is still connectable; destroying it first would strand a working
  /// tunnel with no way to rebuild its config.
  Future<bool> removeDevice(String deviceId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      await ref.read(devicesRepositoryProvider).revoke(deviceId);
      await ref.read(deviceKeyStoreProvider).delete(deviceId);
      await ref.read(tunnelConfigStoreProvider).delete(deviceId);
      _refreshAfterMutation();
    });

    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    return !result.hasError;
  }

  /// Both mutations change the device count, which the profile screen shows and
  /// the add-device flow gates on, and the node load figures on the servers tab.
  void _refreshAfterMutation() {
    ref.invalidate(devicesProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(vpnNodesProvider);
  }
}
