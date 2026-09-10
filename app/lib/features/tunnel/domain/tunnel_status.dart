/// What the platform VPN stack is currently doing.
///
/// Mirrors the states both backends can actually report, which is the reason
/// there is no `connected` shortcut for "handshake succeeded": WireGuard is
/// connectionless, so the interface being up says nothing about whether the peer
/// is answering. [TunnelStats.lastHandshake] is the only real liveness signal.
enum TunnelState {
  /// No interface. The starting state, and where a failed connect lands.
  disconnected,

  /// Interface requested. On Android this covers the system consent dialog, so
  /// it can sit here indefinitely waiting on the user.
  connecting,

  /// Interface is up and carrying routes. Not proof the peer replied.
  connected,

  /// Teardown requested.
  disconnecting;

  bool get isBusy => this == connecting || this == disconnecting;
  bool get isUp => this == connected;
}

/// Transfer counters read from the live interface.
class TunnelStats {
  const TunnelStats({
    required this.rxBytes,
    required this.txBytes,
    this.lastHandshake,
  });

  final int rxBytes;
  final int txBytes;

  /// When the peer last completed a handshake, or null if it never has.
  ///
  /// This is what distinguishes a working tunnel from one that is up but talking
  /// to nothing — a blocked UDP port, a stale endpoint, a revoked peer. WireGuard
  /// rehandshakes about every two minutes while traffic flows, so anything older
  /// than ~3 minutes means the tunnel is effectively dead.
  final DateTime? lastHandshake;

  static const zero = TunnelStats(rxBytes: 0, txBytes: 0);

  /// True when a handshake has happened recently enough to call the peer alive.
  bool get isPeerResponding {
    final at = lastHandshake;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 3);
  }
}

/// A single immutable snapshot of the tunnel, as the UI sees it.
class TunnelStatus {
  const TunnelStatus({
    required this.state,
    this.deviceId,
    this.stats = TunnelStats.zero,
    this.error,
  });

  final TunnelState state;

  /// Which provisioned device this tunnel belongs to, when one is up.
  final String? deviceId;
  final TunnelStats stats;

  /// Why the last connect attempt failed, for display. Null unless it did.
  final String? error;

  static const disconnected = TunnelStatus(state: TunnelState.disconnected);

  factory TunnelStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['state'] as String?;
    return TunnelStatus(
      state: TunnelState.values.firstWhere(
        (s) => s.name == raw,
        // An unrecognised state from a newer native layer must not crash the UI;
        // "disconnected" is the safe reading because it never claims protection
        // that is not there.
        orElse: () => TunnelState.disconnected,
      ),
      deviceId: json['deviceId'] as String?,
      stats: TunnelStats(
        rxBytes: (json['rxBytes'] as num?)?.toInt() ?? 0,
        txBytes: (json['txBytes'] as num?)?.toInt() ?? 0,
        lastHandshake: switch (json['lastHandshakeEpochSeconds']) {
          final num s when s > 0 =>
            DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000),
          _ => null,
        },
      ),
      error: json['error'] as String?,
    );
  }
}
