import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure_log.dart';
import '../../../tunnel/data/tunnel_channel.dart';
import '../../../tunnel/presentation/controller/vpn_session.dart';
import '../../data/excluded_apps_store.dart';
import '../../domain/installed_app.dart';

part 'split_tunnel_controller.g.dart';

/// Every app the picker can offer, straight from the platform.
///
/// `keepAlive` because the list costs a `PackageManager` query per call and does
/// not change while the user is looking at it.
@Riverpod(keepAlive: true)
Future<List<InstalledApp>> installedApps(Ref ref) {
  return ref.watch(tunnelChannelProvider).listApps();
}

/// The packages kept off the tunnel.
///
/// An excluded set only takes effect when an interface is built, so this writes
/// the preference and then rebuilds the tunnel automatically if one is live.
/// Changes are debounced so that rapidly toggling several apps does not cycle
/// the tunnel once per checkbox.
@Riverpod(keepAlive: true)
class ExcludedApps extends _$ExcludedApps {
  Timer? _debounce;

  @override
  Future<Set<String>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return ref.watch(excludedAppsStoreProvider).read();
  }

  Future<void> toggle(String package, {required bool excluded}) async {
    final current = state.value ?? const <String>{};
    final next = {...current};
    if (excluded) {
      next.add(package);
    } else {
      next.remove(package);
    }
    if (next.length == current.length && next.containsAll(current)) return;

    // Optimistic: the keystore is local and sub-millisecond, and a checkbox that
    // waits for it feels broken.
    state = AsyncData(next);
    await ref.read(excludedAppsStoreProvider).write(next);
    _scheduleReconnect();
  }

  Future<void> clear() async {
    final hadExclusions = (state.value ?? const <String>{}).isNotEmpty;
    state = const AsyncData({});
    await ref.read(excludedAppsStoreProvider).write({});
    if (hadExclusions) _scheduleReconnect();
  }

  /// Debounces rapid toggles so a burst of checkboxes produces one reconnect.
  void _scheduleReconnect() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      unawaited(_reconnectIfNeeded());
    });
  }

  /// Rebuilds the tunnel when one is live, so the new exclusion list takes
  /// effect immediately — the same pattern [VpnSession.selectLocation] uses.
  Future<void> _reconnectIfNeeded() async {
    final status = ref.read(tunnelStatusStreamProvider).value;
    if (status == null || !status.state.isUp) return;

    final session = ref.read(vpnSessionProvider.notifier);
    try {
      if (!await session.disconnect()) return;
      await session.connect();
    } catch (error, stack) {
      logFailure('reconnecting after split-tunnel change', error, stack);
    }
  }
}
