/// Mirrors `NodeSummary` from `backend/src/nodes/nodes.service.ts`.
///
/// Note what is *not* here: the node's WireGuard public key, subnet and DNS. The
/// backend withholds those from the fleet listing on purpose and only returns
/// them alongside an issued peer from `POST /devices`, so this model cannot be
/// used to build a tunnel config.
class VpnNode {
  const VpnNode({
    required this.id,
    required this.name,
    required this.region,
    required this.load,
    required this.available,
    this.healthy = true,
  });

  final String id;
  final String name;
  final String region;

  /// 0.0-1.0 — active peers divided by the node's capacity.
  final double load;

  /// False once the node is at `maxPeers`, or once the API has stopped being
  /// able to reach it. A device cannot be issued there either way.
  final bool available;

  /// Whether the API could reach this node's control plane on its last sweep.
  ///
  /// Separate from [available] so the UI can tell a full node from a dead one —
  /// one is worth waiting out and the other is not. Defaults to true when the
  /// field is absent, so an older server reads as a fleet that is simply up
  /// rather than one that is entirely offline.
  final bool healthy;

  factory VpnNode.fromJson(Map<String, dynamic> json) {
    return VpnNode(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      load: (json['load'] as num).toDouble(),
      available: json['available'] as bool,
      healthy: json['healthy'] as bool? ?? true,
    );
  }
}
