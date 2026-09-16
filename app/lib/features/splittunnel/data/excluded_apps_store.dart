import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';

part 'excluded_apps_store.g.dart';

/// The packages the user has chosen to keep off the tunnel.
///
/// Stored in the keystore alongside the other tunnel settings, for the same
/// reason the kill switch preference is: the value is not secret, but "this
/// person routes their banking app around their VPN" is exactly the kind of
/// metadata that has no business in a world-readable preferences file.
///
/// A JSON array under one key rather than a key per package. The set is read and
/// written whole on every change and is small by nature — a picker with hundreds
/// of ticks is not a thing anyone builds — so one round trip beats N.
class ExcludedAppsStore {
  const ExcludedAppsStore(this._store);

  final SecureStore _store;

  static const _key = 'aegis.tunnel.excludedApps';

  /// Defaults to empty: everything goes through the tunnel until told otherwise.
  Future<Set<String>> read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      // A value this app cannot read is worse than none: it would keep apps off
      // the tunnel with no way to see which. Empty means everything is covered,
      // which is the safe reading.
      return {};
    }
  }

  Future<void> write(Set<String> packages) {
    return _store.write(_key, jsonEncode(packages.toList()..sort()));
  }
}

@Riverpod(keepAlive: true)
ExcludedAppsStore excludedAppsStore(Ref ref) {
  return ExcludedAppsStore(ref.watch(secureStoreProvider));
}
