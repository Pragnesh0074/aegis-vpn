import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';

part 'kill_switch_store.g.dart';

/// Remembers whether the user armed the kill switch.
///
/// The platform holds the live flag, but it is process state: it dies with the
/// app. Without a stored copy the kill switch would quietly disarm itself on
/// every restart, which is the one behaviour a protection feature must never
/// have — silently absent is worse than absent.
///
/// Kept in the keystore alongside the other tunnel settings rather than in plain
/// preferences. Not because the value is secret, but because "this person runs a
/// VPN with a kill switch" is the same kind of metadata as which country they
/// exit through, and it has no business in a world-readable file.
class KillSwitchStore {
  const KillSwitchStore(this._store);

  final SecureStore _store;

  static const _key = 'aegis.tunnel.killSwitch';

  /// Defaults to off. Arming it without being asked would rebuild tunnels a user
  /// deliberately dropped.
  Future<bool> read() async => await _store.read(_key) == 'true';

  Future<void> write({required bool enabled}) {
    return _store.write(_key, enabled ? 'true' : 'false');
  }
}

@Riverpod(keepAlive: true)
KillSwitchStore killSwitchStore(Ref ref) {
  return KillSwitchStore(ref.watch(secureStoreProvider));
}
