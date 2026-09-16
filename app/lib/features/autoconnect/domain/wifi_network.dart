/// The Wi-Fi network this device is on, as far as Android will say.
class WifiNetwork {
  const WifiNetwork({required this.ssid, required this.hasPermission});

  /// The network name, or null when there is no Wi-Fi or Android is withholding
  /// it. Those two cases are not distinguished on purpose: neither gives the app
  /// a network it can add to the trusted list.
  final String? ssid;

  /// Whether the location permission Android requires for an SSID is granted.
  /// Without it [ssid] is always null and every network counts as untrusted.
  final bool hasPermission;

  static const unknown = WifiNetwork(ssid: null, hasPermission: false);

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String?,
      hasPermission: json['hasPermission'] as bool? ?? false,
    );
  }
}
