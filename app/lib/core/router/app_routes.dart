/// Every route path, in one place, so no screen builds a path by hand.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  /// Signed-in shell. `home` is the connect screen and the landing tab.
  static const home = '/home';
  static const locations = '/locations';
  static const account = '/account';

  /// Parked, along with the screen itself. An account holds exactly one peer,
  /// so a device list has nothing to list and a quota has nothing to ration —
  /// see `home_routes.dart`. Kept rather than deleted because the single-device
  /// policy is a decision, not an architecture: `vpn_session.dart` names the
  /// line that changes when a phone and a laptop can share an account.
  ///
  /// Declared as a segment as well as a full path: go_router wants the child
  /// route's own `path` relative to its parent, while `context.go` wants the
  /// absolute one.
  static const devicesSegment = 'devices';
  static const devices = '$account/$devicesSegment';

  /// Also under the account tab. Everything that brings the tunnel up or back
  /// up without being asked: auto-connect and the kill switch. A page rather
  /// than rows with switches on them, because what each one does and does not
  /// cover takes more than a subtitle to say honestly.
  static const protectionSegment = 'protection';
  static const protection = '$account/$protectionSegment';

  /// Which apps bypass the tunnel. Its own page because the picker is a list of
  /// every app on the device.
  static const splitTunnelSegment = 'split-tunnel';
  static const splitTunnel = '$account/$splitTunnelSegment';

  /// Past sessions, recorded on this device only.
  static const historySegment = 'history';
  static const history = '$account/$historySegment';

  // The issued-config screen has no path on purpose. It is pushed with the config
  // object itself, which has no id the server would return again — a URL for it
  // could never be reopened.
}
