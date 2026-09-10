/// The token pair returned by every `/auth/*` endpoint that succeeds.
///
/// Mirrors `TokenPair` in `backend/src/auth/auth.types.ts`.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;

  /// Absolute expiry, derived from the API's `expiresIn` (seconds) at the moment
  /// the response arrived. Stored absolute so it survives an app restart.
  final DateTime expiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expiresIn'] as num).toInt();
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  /// Refresh slightly early. The backend's access TTL is short, and a token that
  /// expires mid-flight costs a wasted round trip plus a retry.
  static const _skew = Duration(seconds: 30);

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.subtract(_skew));
}
