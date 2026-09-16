import '../../nodes/domain/region_geo.dart';

/// Mirrors `WhoamiResponse` from `backend/src/whoami/whoami.service.ts`.
///
/// The one fact on the connect screen the app does not assert about itself.
/// Everything else there — the interface state, the handshake counters — is this
/// device describing its own condition, which is exactly what a device cannot be
/// trusted on when the question is whether its traffic is escaping. Here it asks
/// a server what address the packets arrived from.
class ExitCheck {
  const ExitCheck({
    required this.ip,
    required this.viaTunnel,
    required this.node,
    required this.checkedAt,
  });

  /// The source address the API saw. Public when not tunnelled; the exit node's,
  /// or a tunnel address, when it is.
  final String ip;

  /// True when [ip] belongs to the fleet.
  final bool viaTunnel;

  /// Which node [ip] belongs to, or null when it belongs to none.
  final ExitNode? node;

  final DateTime checkedAt;

  /// The country to show, when the address was recognised.
  RegionGeo? get geo => node == null ? null : RegionGeo.parse(node!.region);

  factory ExitCheck.fromJson(Map<String, dynamic> json) {
    return ExitCheck(
      ip: json['ip'] as String,
      viaTunnel: json['viaTunnel'] as bool,
      node: json['node'] == null
          ? null
          : ExitNode.fromJson(json['node'] as Map<String, dynamic>),
      checkedAt: DateTime.parse(json['checkedAt'] as String),
    );
  }
}

/// The node an address was recognised as.
class ExitNode {
  const ExitNode({required this.id, required this.name, required this.region});

  final String id;
  final String name;
  final String region;

  factory ExitNode.fromJson(Map<String, dynamic> json) {
    return ExitNode(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
    );
  }
}
