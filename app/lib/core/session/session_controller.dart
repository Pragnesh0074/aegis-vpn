import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_tokens.dart';
import 'session_store.dart';

part 'session_controller.g.dart';

enum SessionStatus { authenticated, unauthenticated }

/// The single source of truth for "is someone signed in".
///
/// The router watches this, the auth screens write to it, and the Dio interceptor
/// flips it to `unauthenticated` when a refresh token is rejected. Keeping it in
/// core is what lets all three agree without a cycle.
@Riverpod(keepAlive: true)
class SessionNotifier extends _$SessionNotifier {
  /// Async because the first read hits the platform keystore. The splash screen
  /// shows while this resolves, which is also what prevents a one-frame flash of
  /// the login screen for an already-signed-in user.
  @override
  Future<SessionStatus> build() async {
    final tokens = await ref.watch(sessionStoreProvider).read();
    return tokens == null ? SessionStatus.unauthenticated : SessionStatus.authenticated;
  }

  Future<void> signedIn(AuthTokens tokens) async {
    await ref.read(sessionStoreProvider).write(tokens);
    state = const AsyncData(SessionStatus.authenticated);
  }

  /// Drops the local session. Callers that can also reach the network should hit
  /// `/auth/logout` first so the refresh token is revoked server-side, but this
  /// must still run if that call fails — otherwise a user offline can never sign out.
  Future<void> signedOut() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(SessionStatus.unauthenticated);
  }
}
