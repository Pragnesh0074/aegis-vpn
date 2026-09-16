/// Auto-connect's whole configuration: whether it is on, and which networks are
/// exempt.
class AutoConnectSettings {
  const AutoConnectSettings({required this.enabled, required this.trusted});

  final bool enabled;

  /// SSIDs the user has marked safe. Compared case-insensitively by the platform,
  /// because a network differing only in case is the same network.
  final List<String> trusted;

  static const off = AutoConnectSettings(enabled: false, trusted: []);

  bool trusts(String ssid) {
    final needle = ssid.toLowerCase();
    return trusted.any((entry) => entry.toLowerCase() == needle);
  }

  AutoConnectSettings copyWith({bool? enabled, List<String>? trusted}) {
    return AutoConnectSettings(
      enabled: enabled ?? this.enabled,
      trusted: trusted ?? this.trusted,
    );
  }
}
