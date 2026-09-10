import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/session/auth_tokens.dart';

part 'auth_repository.g.dart';

/// Talks to `backend/src/auth/auth.controller.ts`.
///
/// Uses the *public* client: none of these routes take a bearer token, and
/// `/auth/refresh` and `/auth/logout` are `@Public()` precisely because the access
/// token is expected to be expired by the time they are called.
class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  /// `POST /auth/register` → 201 with a token pair.
  ///
  /// A 409 means the email is taken; a 400 carries class-validator messages
  /// (a valid email, and a password of at least 10 characters).
  Future<AuthTokens> register({required String email, required String password}) async {
    final json = await _api.postJson(
      ApiEndpoints.register,
      body: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(json);
  }

  /// `POST /auth/login` → 200 with a token pair.
  ///
  /// The backend answers the same 401 for an unknown email and a wrong password,
  /// on purpose, so there is nothing more specific to show than what it returns.
  Future<AuthTokens> login({required String email, required String password}) async {
    final json = await _api.postJson(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(json);
  }

  /// `POST /auth/logout` → 204. Revokes the refresh token server-side.
  ///
  /// Idempotent on the backend and never fails on a junk token, but it can still
  /// fail to *arrive*. Callers must clear the local session regardless.
  Future<void> logout(String refreshToken) async {
    try {
      await _api.postEmpty(ApiEndpoints.logout, body: {'refreshToken': refreshToken});
    } on NetworkException {
      // Offline sign-out: the local session still goes away. The token expires on
      // its own, and reuse detection covers the rest.
    }
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(publicApiClientProvider));
