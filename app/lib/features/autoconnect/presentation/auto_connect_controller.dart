import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/failure_log.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../data/auto_connect_store.dart';
import '../domain/auto_connect_settings.dart';
import '../domain/wifi_network.dart';

part 'auto_connect_controller.g.dart';

/// Auto-connect, and the job of keeping the platform in step with it.
///
/// Same two-sources-of-truth shape as the kill switch, for the same reason: the
/// stored preference survives a restart, the platform flag is what actually
/// watches for networks and dies with the process. The platform is told first —
/// a stored `true` the platform never heard about is a feature that silently
/// does nothing.
@Riverpod(keepAlive: true)
class AutoConnect extends _$AutoConnect {
  @override
  Future<AutoConnectSettings> build() async {
    final settings = await ref.watch(autoConnectStoreProvider).read();

    try {
      await _push(settings);
    } catch (error, stack) {
      logFailure('arming auto-connect', error, stack);
      // Reported as off, which is also the truth about what is watching.
      return AutoConnectSettings.off;
    }
    return settings;
  }

  Future<void> setEnabled({required bool enabled}) {
    return _apply((current) => current.copyWith(enabled: enabled));
  }

  /// Adds the network this device is on to the trusted list.
  ///
  /// Reads the SSID from the platform rather than taking it as an argument:
  /// typing a network name from memory is how someone ends up trusting a name
  /// they are not actually on, and a trusted network that does not match is a
  /// tunnel that comes up where they did not want one — which is the harmless
  /// direction, but still not what they asked for.
  ///
  /// Returns the name added, or null when Android would not name the network.
  Future<String?> trustCurrentNetwork() async {
    final wifi = await ref.read(tunnelChannelProvider).currentWifi();
    final ssid = wifi.ssid;
    if (ssid == null) return null;

    final current = state.value ?? AutoConnectSettings.off;
    if (current.trusts(ssid)) return ssid;

    await _apply((settings) => settings.copyWith(trusted: [...settings.trusted, ssid]));
    return ssid;
  }

  /// Trusts [ssid] by name.
  ///
  /// The by-name counterpart to [trustCurrentNetwork], for the two cases where
  /// the user is deciding about a network they are not standing on: the
  /// notification's action, and the "recently joined" list. Both supply a name
  /// the device genuinely connected to, which is what makes taking one safe here
  /// when typing one would not be.
  Future<void> trust(String ssid) async {
    final current = state.value ?? AutoConnectSettings.off;
    if (current.trusts(ssid)) return;
    await _apply((settings) => settings.copyWith(trusted: [...settings.trusted, ssid]));
  }

  /// Records a network the device joined, so it can be trusted later.
  ///
  /// Cheap and idempotent: called on every status emit that names a network, and
  /// does nothing when that network is already the most recent one.
  Future<void> remember(String ssid) async {
    final current = state.value ?? AutoConnectSettings.off;
    if (current.seen.isNotEmpty && current.seen.first == ssid) return;
    await _apply((settings) => settings.remember(ssid));
  }

  Future<void> forget(String ssid) {
    return _apply(
      (settings) => settings.copyWith(
        trusted: settings.trusted.where((entry) => entry != ssid).toList(),
      ),
    );
  }

  /// Asks for the location permission Android requires before naming a network.
  ///
  /// Rebuilds afterwards so the screen re-reads whether it was granted; the
  /// platform reports that in the status snapshot, but only on the next emit.
  Future<bool> requestPermission() async {
    final granted = await ref.read(tunnelChannelProvider).requestWifiPermission();
    if (granted) ref.invalidateSelf();
    return granted;
  }

  Future<void> _apply(
    AutoConnectSettings Function(AutoConnectSettings current) change,
  ) async {
    final previous = state;
    final next = change(state.value ?? AutoConnectSettings.off);
    state = AsyncData(next);

    try {
      await _push(next);
      await ref.read(autoConnectStoreProvider).write(next);
    } catch (error, stack) {
      logFailure('changing auto-connect', error, stack);
      // Snap back rather than leave the screen claiming a watch that is not
      // running.
      state = previous;
      rethrow;
    }
  }

  Future<void> _push(AutoConnectSettings settings) {
    return ref.read(tunnelChannelProvider).setAutoConnect(
          enabled: settings.enabled,
          trusted: settings.trusted,
        );
  }
}

/// The network this device is on right now, for the "trust this network" row.
///
/// Auto-disposing and re-read each time the screen is opened, because it is the
/// one value here that changes without the app doing anything.
@riverpod
Future<WifiNetwork> currentWifi(Ref ref) {
  return ref.watch(tunnelChannelProvider).currentWifi();
}
