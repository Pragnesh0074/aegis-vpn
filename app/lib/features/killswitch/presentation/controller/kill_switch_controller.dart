import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure_log.dart';
import '../../../tunnel/data/tunnel_channel.dart';
import '../../data/kill_switch_store.dart';

part 'kill_switch_controller.g.dart';

/// The kill switch setting, and the job of keeping the platform in step with it.
///
/// Two sources of truth have to be reconciled. The stored preference survives
/// restarts; the platform flag is what actually rebuilds a dropped tunnel and is
/// lost when the process dies. So the stored value is pushed down to the platform
/// on first read, and every change is written to both.
///
/// The platform is told first. If that fails there is nothing to persist — a
/// stored `true` whose platform never heard about it is exactly the silent
/// no-protection case this feature exists to avoid.
@Riverpod(keepAlive: true)
class KillSwitchController extends _$KillSwitchController {
  @override
  Future<bool> build() async {
    final enabled = await ref.watch(killSwitchStoreProvider).read();

    // Re-arm the platform for this process. Failing here must not leave the
    // screen unable to render, so it is reported as the setting being off rather
    // than as an error — which is also the truth about what is armed.
    try {
      await ref.read(tunnelChannelProvider).setKillSwitch(enabled: enabled);
    } catch (error, stack) {
      logFailure('arming the kill switch', error, stack);
      return false;
    }
    return enabled;
  }

  Future<void> setEnabled({required bool enabled}) async {
    if (state.value == enabled && !state.hasError) return;

    final previous = state;
    state = AsyncData(enabled);

    try {
      await ref.read(tunnelChannelProvider).setKillSwitch(enabled: enabled);
      await ref.read(killSwitchStoreProvider).write(enabled: enabled);
    } catch (error, stack) {
      logFailure('changing the kill switch', error, stack);
      // Snap back rather than leave a toggle claiming protection that is not
      // armed.
      state = previous;
      rethrow;
    }
  }

  /// Hands the user to Android's own "Block connections without VPN".
  ///
  /// Returns false when the device has no VPN settings screen to open.
  Future<bool> openSystemVpnSettings() {
    return ref.read(tunnelChannelProvider).openVpnSettings();
  }
}
