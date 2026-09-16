import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';
import '../domain/vpn_session_record.dart';

part 'session_history_store.g.dart';

/// Where finished sessions are kept: on this device, in the keystore, and
/// nowhere else.
class SessionHistoryStore {
  const SessionHistoryStore(this._store);

  final SecureStore _store;

  static const _key = 'aegis.tunnel.sessions';

  /// How many sessions are kept.
  ///
  /// A cap rather than a retention window, because the whole list is serialised
  /// on every write and an unbounded one would grow until a write became slow
  /// enough to notice. Fifty covers weeks of ordinary use and is a few kilobytes.
  static const limit = 50;

  /// Newest first, which is both how they are stored and how they are shown.
  Future<List<VpnSessionRecord>> read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(VpnSessionRecord.tryParse)
          .whereType<VpnSessionRecord>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  /// Prepends [record] and trims to [limit].
  Future<void> add(VpnSessionRecord record) async {
    final existing = await read();
    final next = [record, ...existing].take(limit).toList();
    await _store.write(_key, jsonEncode([for (final row in next) row.toJson()]));
  }

  Future<void> clear() => _store.delete(_key);
}

@Riverpod(keepAlive: true)
SessionHistoryStore sessionHistoryStore(Ref ref) {
  return SessionHistoryStore(ref.watch(secureStoreProvider));
}
