/// Build-time configuration.
///
/// Every value comes from `--dart-define`, so the same binary can be pointed at a
/// local API or production without a code change and without secrets in the repo.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  /// Base URL of the NestJS API. The backend mounts routes at the root (no global
  /// prefix), so this is the bare origin — `/auth/login`, `/devices`, `/nodes`.
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// The deployed API, so a plain `flutter run` reaches a working backend.
  ///
  /// Override it to develop against a backend on your own machine — note the
  /// host differs by platform, because "localhost" means the device itself:
  ///
  ///     # iOS simulator (shares the host's network stack)
  ///     flutter run --dart-define=API_BASE_URL=http://localhost:3000
  ///     # Android emulator (10.0.2.2 is its alias for the host)
  ///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  ///     # physical device (your machine's address on the LAN)
  ///     flutter run --dart-define=API_BASE_URL=http://192.168.1.x:3000
  ///
  /// This is plain HTTP, which Android 9+ blocks unless cleartext is allowed —
  /// `android/app/src/debug/AndroidManifest.xml` does so for debug builds only.
  /// Release builds keep it disabled, so this default has to become `https://`
  /// once the API is behind TLS.
  ///
  /// A bare IP, and the instance has no Elastic IP, so every stop/start of the
  /// EC2 host changes it and this constant has to be edited and the app rebuilt.
  /// That is understood and accepted for the MVP; the fix is an Elastic IP, or a
  /// domain, either of which makes this value stable.
  static const _defaultBaseUrl = 'http://13.201.76.135:3000';

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultBaseUrl,
      ),
      connectTimeout: Duration(seconds: 15),
      receiveTimeout: Duration(seconds: 20),
    );
  }

  /// True when talking to a plain-HTTP origin, which only a dev build should do.
  bool get isInsecureLocal => apiBaseUrl.startsWith('http://');
}
