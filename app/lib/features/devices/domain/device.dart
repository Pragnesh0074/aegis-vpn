/// Mirrors `DeviceSummary` from `backend/src/devices/device.response.ts`.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.tunnelIp,
    required this.createdAt,
    required this.lastSeenAt,
    required this.node,
  });

  final String id;
  final String name;
  final String platform;

  /// Already carries the `/32` suffix — the backend appends it.
  final String tunnelIp;

  final DateTime createdAt;

  /// Null until the peer has handshaked at least once.
  final DateTime? lastSeenAt;

  final DeviceNode node;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      tunnelIp: json['tunnelIp'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.parse(json['lastSeenAt'] as String),
      node: DeviceNode.fromJson(json['node'] as Map<String, dynamic>),
    );
  }
}

/// The trimmed node shape embedded in a device response — id, name, region only.
class DeviceNode {
  const DeviceNode({required this.id, required this.name, required this.region});

  final String id;
  final String name;
  final String region;

  factory DeviceNode.fromJson(Map<String, dynamic> json) {
    return DeviceNode(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'region': region};
}

/// The platform values `CreateDeviceDto` accepts.
enum DevicePlatform {
  android('android', 'Android'),
  ios('ios', 'iOS'),
  macos('macos', 'macOS'),
  windows('windows', 'Windows'),
  linux('linux', 'Linux');

  const DevicePlatform(this.wireValue, this.label);

  /// Exactly what goes on the wire — `@IsIn(PLATFORMS)` rejects anything else.
  final String wireValue;
  final String label;

  static DevicePlatform? tryParse(String value) {
    for (final platform in DevicePlatform.values) {
      if (platform.wireValue == value) return platform;
    }
    return null;
  }

  /// A label for a platform string the app does not know, so a value added on the
  /// server later still renders instead of crashing the list.
  static String labelFor(String value) => tryParse(value)?.label ?? value;
}
