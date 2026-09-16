/// One app the user could keep off the tunnel.
///
/// Only apps with a launcher icon appear — see `listApps` in `TunnelBridge.kt`
/// for why — so this is the set a person would recognise by name, not every
/// package on the device.
class InstalledApp {
  const InstalledApp({
    required this.package,
    required this.label,
    required this.isSystem,
  });

  /// The package name, which is what the platform excludes by.
  final String package;

  /// The name the launcher shows.
  final String label;

  /// True for apps that shipped with the device. Shown as a hint rather than
  /// hidden: a carrier's own app is a plausible thing to exclude.
  final bool isSystem;

  factory InstalledApp.fromJson(Map<String, dynamic> json) {
    return InstalledApp(
      package: json['package'] as String,
      label: json['label'] as String? ?? json['package'] as String,
      isSystem: json['system'] as bool? ?? false,
    );
  }

  /// Whether this app matches a picker query. Package included, so someone who
  /// knows exactly what they are looking for can type it.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        package.toLowerCase().contains(needle);
  }
}
