/// Every route path, in one place, so no screen builds a path by hand.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  /// Signed-in shell. `home` is the connect screen and the landing tab.
  static const home = '/home';
  static const locations = '/locations';
  static const account = '/account';

  /// Pushed from the account tab, not a tab of its own. Devices are plumbing
  /// now that connecting provisions a peer on its own — the list is there to
  /// revoke a peer issued on a phone the user no longer has, not to add one.
  ///
  /// Declared as a segment as well as a full path: go_router wants the child
  /// route's own `path` relative to its parent, while `context.go` wants the
  /// absolute one.
  static const devicesSegment = 'devices';
  static const devices = '$account/$devicesSegment';

  /// Also under the account tab. The kill switch needs a page rather than a
  /// row with a switch on it, because what it does and does not cover takes
  /// more than a subtitle to say honestly.
  static const killSwitchSegment = 'kill-switch';
  static const killSwitch = '$account/$killSwitchSegment';

  // The issued-config screen has no path on purpose. It is pushed with the config
  // object itself, which has no id the server would return again — a URL for it
  // could never be reopened.
}
