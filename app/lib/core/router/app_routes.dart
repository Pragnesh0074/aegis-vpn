/// Every route path, in one place, so no screen builds a path by hand.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  /// Signed-in shell. `devices` is the landing tab.
  static const devices = '/devices';
  static const servers = '/servers';
  static const profile = '/profile';

  // The issued-config screen has no path on purpose. It is pushed with the config
  // object itself, which has no id the server would return again — a URL for it
  // could never be reopened.
}
