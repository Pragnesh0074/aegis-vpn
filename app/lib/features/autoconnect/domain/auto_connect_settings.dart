/// Auto-connect's whole configuration: whether it is on, and which networks are
/// exempt.
class AutoConnectSettings {
  const AutoConnectSettings({
    required this.enabled,
    required this.trusted,
    this.seen = const [],
  });

  final bool enabled;

  /// SSIDs the user has marked safe. Compared case-insensitively by the platform,
  /// because a network differing only in case is the same network.
  final List<String> trusted;

  /// Networks this device has actually joined, newest first.
  ///
  /// Kept so the user can mark a network trusted without standing on it, which
  /// is the only way to pre-trust the office from home. Deliberately not a scan
  /// of nearby networks: that needs location services switched on, is throttled
  /// by Android, and would list every neighbour's router — noise, for a list
  /// whose whole value is that it contains only networks that matter.
  final List<String> seen;

  /// Bounded so a phone that has been to a lot of cafés does not grow this
  /// without limit.
  static const maxSeen = 15;

  static const off = AutoConnectSettings(enabled: false, trusted: []);

  /// Joined networks that are not already trusted — the ones worth offering.
  List<String> get untrustedSeen =>
      seen.where((ssid) => !trusts(ssid)).toList(growable: false);

  /// Records [ssid] as joined, newest first and without duplicates.
  AutoConnectSettings remember(String ssid) {
    final needle = ssid.toLowerCase();
    final rest = seen.where((entry) => entry.toLowerCase() != needle);
    return copyWith(seen: [ssid, ...rest].take(maxSeen).toList(growable: false));
  }

  bool trusts(String ssid) {
    final needle = ssid.toLowerCase();
    return trusted.any((entry) => entry.toLowerCase() == needle);
  }

  AutoConnectSettings copyWith({
    bool? enabled,
    List<String>? trusted,
    List<String>? seen,
  }) {
    return AutoConnectSettings(
      enabled: enabled ?? this.enabled,
      trusted: trusted ?? this.trusted,
      seen: seen ?? this.seen,
    );
  }
}
