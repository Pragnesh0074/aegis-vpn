/// Everything the UI is allowed to see about a failure.
///
/// The backend's `AllExceptionsFilter` returns one shape for every error:
/// `{ statusCode, message: string | string[], error?, path, timestamp }`.
/// `ApiException.fromResponse` is the single place that shape is parsed, so no
/// widget or repository ever pokes at raw JSON.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// A message safe to show a user.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never reached the API — no connectivity, DNS failure, timeout.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Cannot reach the server. Check your connection.']);
}

/// The API answered with a non-2xx status.
class ApiException extends AppException {
  ApiException({
    required this.statusCode,
    required this.messages,
    this.error,
  }) : super(messages.isEmpty ? 'Request failed ($statusCode)' : messages.first);

  final int statusCode;

  /// class-validator returns an array of messages for a 400; everything else
  /// returns a single string. Both are normalised to a list here.
  final List<String> messages;

  /// The `error` field, e.g. `Bad Request`. Absent on most responses.
  final String? error;

  factory ApiException.fromResponse(int? statusCode, Object? body) {
    final status = statusCode ?? 0;
    if (body is! Map) {
      return ApiException(statusCode: status, messages: const []);
    }

    final raw = body['message'];
    final messages = switch (raw) {
      String s when s.isNotEmpty => [s],
      List list => list.map((e) => e.toString()).toList(),
      _ => <String>[],
    };

    return ApiException(
      statusCode: status,
      messages: messages,
      error: body['error'] as String?,
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 400;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  /// 429 from the throttler. `/auth/login` allows 5 per minute, so this is
  /// reachable in normal use and deserves its own message.
  bool get isRateLimited => statusCode == 429;
}

/// A refresh token was rejected or is gone. The session is unrecoverable and the
/// app must return to the login screen.
class SessionExpiredException extends AppException {
  const SessionExpiredException([super.message = 'Your session expired. Please sign in again.']);
}

/// Something failed on the device — key generation, secure storage, a decode.
class LocalException extends AppException {
  const LocalException(super.message);
}
