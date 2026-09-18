import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';
import '../domain/auto_connect_settings.dart';

part 'auto_connect_store.g.dart';

/// Remembers auto-connect's setting and its trusted networks.
///
/// The platform holds the live copy, but that is process state and dies with the
/// app — the same problem the kill switch has, with the same answer. One key
/// holding both halves, because a flag armed against a trusted list that failed
/// to load would connect on the one network the user told it not to.
///
/// In the keystore rather than plain preferences: a list of the Wi-Fi networks
/// someone considers home is a map of where they live and work.
class AutoConnectStore {
  const AutoConnectStore(this._store);

  final SecureStore _store;

  static const _key = 'aegis.tunnel.autoConnect';

  /// Defaults to off. Connecting on its own is not a behaviour to assume.
  Future<AutoConnectSettings> read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return AutoConnectSettings.off;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AutoConnectSettings.off;
      return AutoConnectSettings(
        enabled: decoded['enabled'] == true,
        trusted: (decoded['trusted'] as List?)?.whereType<String>().toList() ?? const [],
        seen: (decoded['seen'] as List?)?.whereType<String>().toList() ?? const [],
      );
    } on FormatException {
      // Unreadable reads as off rather than as on-with-no-trusted-networks: the
      // second would start connecting on networks the user had exempted.
      return AutoConnectSettings.off;
    }
  }

  Future<void> write(AutoConnectSettings settings) {
    return _store.write(
      _key,
      jsonEncode({
        'enabled': settings.enabled,
        'trusted': settings.trusted,
        'seen': settings.seen,
      }),
    );
  }
}

@Riverpod(keepAlive: true)
AutoConnectStore autoConnectStore(Ref ref) {
  return AutoConnectStore(ref.watch(secureStoreProvider));
}
