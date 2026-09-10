import 'package:dio/dio.dart';

import '../error/app_exception.dart';
import '../session/auth_tokens.dart';
import '../session/session_store.dart';
import 'api_endpoints.dart';

/// Attaches the bearer token and transparently rotates it.
///
/// Two behaviours worth knowing:
///
/// 1. **Proactive refresh.** Access tokens are short-lived, so rather than let a
///    request fail and retry, an expired token is exchanged before the request
///    goes out.
/// 2. **Single-flight.** A screen that fires three requests at once would otherwise
///    send three refreshes. Only the first wins — the backend rotates refresh
///    tokens and treats reuse of an already-rotated one as theft (it revokes the
///    whole family), so a concurrent double-refresh would log the user out.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SessionStore store,
    required Dio refreshClient,
    required Future<void> Function() onSessionExpired,
  }) : _store = store,
       _refreshClient = refreshClient,
       _onSessionExpired = onSessionExpired;

  final SessionStore _store;

  /// A Dio with no interceptors, so refreshing cannot recurse into itself.
  final Dio _refreshClient;

  final Future<void> Function() _onSessionExpired;

  Future<AuthTokens>? _inFlight;

  /// Routes that must never carry (or wait for) a bearer token. `/auth/refresh`
  /// and `/auth/logout` are `@Public()` on the backend and authenticate with the
  /// refresh token in the body instead.
  static const _anonymous = {
    ApiEndpoints.register,
    ApiEndpoints.login,
    ApiEndpoints.refresh,
    ApiEndpoints.logout,
    ApiEndpoints.health,
  };

  static bool _isAnonymous(RequestOptions options) => _anonymous.contains(options.path);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isAnonymous(options)) return handler.next(options);

    var tokens = await _store.read();
    if (tokens == null) {
      // No session at all. Fail locally instead of sending a request that is
      // certain to come back 401.
      return handler.reject(
        DioException(
          requestOptions: options,
          error: const SessionExpiredException('You are not signed in.'),
          type: DioExceptionType.cancel,
        ),
        true,
      );
    }

    if (tokens.isExpired) {
      try {
        tokens = await _refresh(tokens.refreshToken);
      } on AppException catch (error) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: error,
            type: DioExceptionType.cancel,
          ),
          true,
        );
      }
    }

    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final shouldRetry = err.response?.statusCode == 401 &&
        !_isAnonymous(options) &&
        options.extra['retried'] != true;

    if (!shouldRetry) return handler.next(err);

    final current = await _store.read();
    if (current == null) return handler.next(err);

    final AuthTokens rotated;
    try {
      rotated = await _refresh(current.refreshToken);
    } on AppException catch (error) {
      return handler.reject(
        DioException(requestOptions: options, error: error, type: DioExceptionType.cancel),
      );
    }

    // `retried` stops a server that answers 401 even with a fresh token from
    // putting us in an endless refresh loop.
    options.extra['retried'] = true;
    options.headers['Authorization'] = 'Bearer ${rotated.accessToken}';

    try {
      final response = await _refreshClient.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens> _refresh(String refreshToken) {
    return _inFlight ??= _performRefresh(refreshToken).whenComplete(() => _inFlight = null);
  }

  Future<AuthTokens> _performRefresh(String refreshToken) async {
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await _store.write(tokens);
      return tokens;
    } on DioException catch (error) {
      final status = error.response?.statusCode;

      // A 401 means the refresh token is revoked, rotated or expired: the session
      // is gone for good. Anything else (offline, 500, a 429 from the throttler)
      // is transient and must NOT wipe a still-valid session.
      if (status == 401) {
        await _store.clear();
        await _onSessionExpired();
        throw const SessionExpiredException();
      }
      if (status != null) {
        throw ApiException.fromResponse(status, error.response?.data);
      }
      throw const NetworkException();
    }
  }
}
