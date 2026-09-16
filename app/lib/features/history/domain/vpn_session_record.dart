/// One completed tunnel session.
///
/// Written when the interface goes down, from counters the app was already
/// computing for the connect screen and then throwing away. Nothing here leaves
/// the device and nothing is reported to the API — a record of when someone used
/// a VPN and how much they moved through it is precisely the log this product
/// exists so that nobody else keeps.
class VpnSessionRecord {
  const VpnSessionRecord({
    required this.startedAt,
    required this.endedAt,
    required this.rxBytes,
    required this.txBytes,
    this.nodeName,
    this.region,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// Totals across the whole session, carried over interface rebuilds — a kill
  /// switch reconnect restarts WireGuard's counters at zero, and a session that
  /// survived one must not report only what moved after it.
  final int rxBytes;
  final int txBytes;

  /// The node this session exited through, when it could be resolved. Null for a
  /// session whose cached config had already been replaced.
  final String? nodeName;
  final String? region;

  Duration get duration => endedAt.difference(startedAt);

  int get totalBytes => rxBytes + txBytes;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'rxBytes': rxBytes,
        'txBytes': txBytes,
        'nodeName': nodeName,
        'region': region,
      };

  static VpnSessionRecord? tryParse(Object? json) {
    if (json is! Map) return null;
    try {
      return VpnSessionRecord(
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        rxBytes: (json['rxBytes'] as num?)?.toInt() ?? 0,
        txBytes: (json['txBytes'] as num?)?.toInt() ?? 0,
        nodeName: json['nodeName'] as String?,
        region: json['region'] as String?,
      );
    } catch (_) {
      // One unreadable row must not cost the user the rest of their history.
      return null;
    }
  }
}
