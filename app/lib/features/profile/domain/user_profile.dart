/// Mirrors `UserProfile` from `backend/src/users/users.service.ts`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.deviceCount,
    required this.maxDevices,
  });

  final String id;
  final String email;
  final DateTime createdAt;

  /// Devices that currently hold a WireGuard peer. Revoked devices are soft
  /// deleted on the backend and deliberately excluded, which is why this can go
  /// down after removing a device.
  final int deviceCount;

  /// `MAX_DEVICES_PER_USER` on the server. The same number gates `POST /devices`,
  /// so the app can disable "add device" before the request would 409.
  final int maxDevices;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deviceCount: (json['deviceCount'] as num).toInt(),
      maxDevices: (json['maxDevices'] as num).toInt(),
    );
  }

  bool get hasDeviceCapacity => deviceCount < maxDevices;
  int get remainingDevices => (maxDevices - deviceCount).clamp(0, maxDevices);
}
