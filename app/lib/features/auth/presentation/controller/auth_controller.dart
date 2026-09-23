import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/session/auth_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/session/session_store.dart';
import '../../data/auth_repository.dart';

part 'auth_controller.g.dart';

/// Drives the sign-in and sign-up forms.
///
/// Holds only submission state — whether a request is in flight and whether it
/// failed. Who is signed in lives in [sessionProvider]; duplicating it here would
/// give the app two answers to the same question.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  Future<void> register({required String email, required String password}) {
    return _submit(
      () => ref
          .read(authRepositoryProvider)
          .register(email: email.trim(), password: password),
    );
  }

  Future<void> login({required String email, required String password}) {
    return _submit(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password),
    );
  }

  /// Revokes the refresh token server-side, then drops the local session.
  ///
  /// The local clear runs even if the network call fails — otherwise a user with
  /// no connectivity could never sign out of their own phone.
  Future<void> signOut() async {
    final tokens = await ref.read(sessionStoreProvider).read();
    try {
      if (tokens != null) {
        await ref.read(authRepositoryProvider).logout(tokens.refreshToken);
      }
    } finally {
      await ref.read(sessionProvider.notifier).signedOut();
    }
  }

  Future<void> _submit(Future<AuthTokens> Function() request) async {
    if (state.isLoading) return; // ignore a double tap on the submit button

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens = await request();
      // Persisting the pair is what flips [sessionProvider] to authenticated and
      // moves the router off the auth screens.
      await ref.read(sessionProvider.notifier).signedIn(tokens);
    });
  }
}
