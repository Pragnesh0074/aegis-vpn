/// Mirrors `UserProfile` from `backend/src/users/users.service.ts`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.deviceCount,
    required this.maxDevices,
    required this.adBlockEnabled,
    required this.adBlockEntitled,
    required this.access,
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

  /// What the user asked for. Stored even when the plan does not allow it, so the
  /// preference survives a lapsed subscription.
  final bool adBlockEnabled;

  /// Whether their plan allows ad blocking at all. Both are sent so the UI can say
  /// *why* the switch is off rather than just showing it off.
  final bool adBlockEntitled;

  /// Paid access, and on what basis. The one place the UI asks "may they?".
  final AccessState access;

  /// What is actually in force. [adBlockEnabled] alone would lie to a user whose
  /// plan does not include it.
  bool get adBlockActive => adBlockEnabled && adBlockEntitled;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deviceCount: (json['deviceCount'] as num).toInt(),
      maxDevices: (json['maxDevices'] as num).toInt(),
      // Defaulted so an older server that does not send them still parses.
      adBlockEnabled: json['adBlockEnabled'] as bool? ?? true,
      adBlockEntitled: json['adBlockEntitled'] as bool? ?? true,
      access: AccessState.fromJson(json['access'] as Map<String, dynamic>?),
    );
  }

  bool get hasDeviceCapacity => deviceCount < maxDevices;
  int get remainingDevices => (maxDevices - deviceCount).clamp(0, maxDevices);
}

/// Mirrors `AccessState` on the API.
///
/// Every account gets 24 hours from sign-up, then needs a subscription. The
/// server decides — the client never does the date arithmetic itself, because a
/// device clock is not something entitlement should depend on.
class AccessState {
  const AccessState({
    required this.entitled,
    required this.onTrial,
    required this.subscribed,
    required this.remaining,
  });

  /// True when the paid features are available right now.
  final bool entitled;

  /// True when that is the free trial rather than a subscription.
  final bool onTrial;
  final bool subscribed;

  /// How long that access lasts. [Duration.zero] once it has lapsed.
  final Duration remaining;

  /// An older server that does not send this is treated as entitled. Failing
  /// open is right here: locking someone out of what they paid for because a
  /// field was missing is worse than a day of free access.
  factory AccessState.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AccessState(
        entitled: true,
        onTrial: false,
        subscribed: false,
        remaining: Duration.zero,
      );
    }
    return AccessState(
      entitled: json['entitled'] as bool? ?? true,
      onTrial: json['onTrial'] as bool? ?? false,
      subscribed: json['subscribed'] as bool? ?? false,
      remaining: Duration(milliseconds: (json['remainingMs'] as num?)?.toInt() ?? 0),
    );
  }

  /// Rounded up, because "0 hours left" reads as expired when it is not.
  int get hoursLeft => remaining.inMinutes <= 0 ? 0 : (remaining.inMinutes / 60).ceil();
}
