import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../devices/data/device_key_store.dart';
import '../data/tunnel_channel.dart';
import '../data/tunnel_config_store.dart';
import '../domain/tunnel_status.dart';

part 'tunnel_controller.g.dart';

/// Drives connect and disconnect.
///
/// Deliberately does not hold the tunnel state: that comes from
/// [tunnelStatusStreamProvider], because the platform can take the tunnel down
/// without asking. This notifier's own state is only the progress of a command
/// the user issued, so a failed connect can show an error while the status card
/// keeps reporting what is actually true.
@riverpod
class TunnelController extends _$TunnelController {
  @override
  FutureOr<void> build() {}

  /// Starts the tunnel for a provisioned device.
  ///
  /// Both halves of the config have to be present: the cached peer details and
  /// the private key. Either can be missing on a phone that did not issue this
  /// peer, and neither is recoverable — `GET /devices` will not re-issue the peer
  /// details and the private key was never uploaded. So this reports a clear
  /// dead end rather than a transport error.
  Future<bool> connect(String deviceId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      final config = await ref.read(tunnelConfigStoreProvider).read(deviceId);
      final privateKey = await ref.read(deviceKeyStoreProvider).read(deviceId);

      if (config == null || privateKey == null) {
        throw const TunnelException(
          'This device was set up on another phone, so its key is not here. '
          'Remove it and add a new device to connect.',
        );
      }

      await ref
          .read(tunnelChannelProvider)
          .connect(config: config, privateKey: privateKey);
      await ref.read(tunnelConfigStoreProvider).saveSelectedDeviceId(deviceId);
    });

    if (result.hasError) logFailure('connect', result.error!, result.stackTrace!);
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !result.hasError;
  }

  Future<bool> disconnect() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      await ref.read(tunnelChannelProvider).disconnect();
    });

    if (result.hasError) logFailure('disconnect', result.error!, result.stackTrace!);
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !result.hasError;
  }

  /// Toggle used by the connect button, so the UI does not have to decide which
  /// direction it is going while a state change is in flight.
  Future<bool> toggle(String deviceId) {
    final current = ref
        .read(tunnelStatusStreamProvider)
        .value
        ?.state ??
        TunnelState.disconnected;
    return current.isUp ? disconnect() : connect(deviceId);
  }
}

/// True only when this specific device is the one carrying traffic.
///
/// The list shows a badge per device, and exactly one tunnel can be up at a time,
/// so each row needs to know whether it is the live one rather than just whether
/// *a* tunnel exists.
@riverpod
bool isDeviceConnected(Ref ref, String deviceId) {
  final status = ref.watch(tunnelStatusStreamProvider).value;
  return status != null && status.state.isUp && status.deviceId == deviceId;
}
