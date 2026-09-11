import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../nodes/presentation/nodes_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/data/tunnel_config_store.dart';
import '../../tunnel/presentation/vpn_session.dart';
import '../data/device_key_store.dart';
import '../data/devices_repository.dart';
import 'devices_providers.dart';

part 'devices_controller.g.dart';

/// Revoking a peer from the device list.
///
/// Issuing one lives in `VpnSession` instead, because it now happens as part of
/// connecting rather than as its own user-facing step. Reads stay in
/// [devicesProvider]: keeping them apart means a failed revoke shows an error
/// without blanking the list the user is looking at.
@riverpod
class DevicesController extends _$DevicesController {
  @override
  FutureOr<void> build() {}

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

  /// Revoking changes the device count the account screen shows and the load
  /// figures on the locations screen.
  ///
  /// [provisionedDeviceProvider] matters most: revoking the peer this phone was
  /// driving must not leave the connect screen believing it still has one, or
  /// the next tap would try to bring up an interface for a peer the server has
  /// already forgotten.
  void _refreshAfterMutation() {
    ref
      ..invalidate(devicesProvider)
      ..invalidate(userProfileProvider)
      ..invalidate(vpnNodesProvider)
      ..invalidate(provisionedDeviceProvider);
  }
}
