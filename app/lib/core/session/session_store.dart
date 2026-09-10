import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/secure_store.dart';
import 'auth_tokens.dart';

part 'session_store.g.dart';

/// Persists the token pair in the platform keystore.
///
/// Kept out of the auth feature on purpose: the Dio interceptor in `core/network`
/// needs to read and rotate tokens, and core must not depend on a feature.
class SessionStore {
  const SessionStore(this._store);

  static const _key = 'aegis.session.v1';

  final SecureStore _store;

  Future<AuthTokens?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
    } catch (_) {
      // A shape we cannot read is treated as no session rather than a crash on
      // launch — the only cost is one sign-in.
      await clear();
      return null;
    }
  }

  Future<void> write(AuthTokens tokens) {
    return _store.write(
      _key,
      jsonEncode({
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
        'expiresAt': tokens.expiresAt.toIso8601String(),
      }),
    );
  }

  Future<void> clear() => _store.delete(_key);
}

@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => SessionStore(ref.watch(secureStoreProvider));
