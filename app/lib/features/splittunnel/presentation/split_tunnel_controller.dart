import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../tunnel/data/tunnel_channel.dart';
import '../data/excluded_apps_store.dart';
import '../domain/installed_app.dart';

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
/// Nothing is pushed to the platform here, and that is deliberate. An excluded
/// set only takes effect when an interface is built, so this writes the
/// preference and the next `connect` carries it — which also means a change made
/// while the tunnel is up does nothing until it is rebuilt. The screen says so
/// rather than silently reconnecting: dropping someone's tunnel because they
/// ticked a checkbox is a worse surprise than a banner asking them to.
@Riverpod(keepAlive: true)
class ExcludedApps extends _$ExcludedApps {
  @override
  Future<Set<String>> build() => ref.watch(excludedAppsStoreProvider).read();

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
  }

  Future<void> clear() async {
    state = const AsyncData({});
    await ref.read(excludedAppsStoreProvider).write({});
  }
}
