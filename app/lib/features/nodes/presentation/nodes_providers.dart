import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/nodes_repository.dart';
import '../domain/vpn_node.dart';

part 'nodes_providers.g.dart';

/// The active node fleet.
///
/// `keepAlive` so the picker on the add-device sheet does not re-fetch the list
/// the servers tab already has.
@Riverpod(keepAlive: true)
Future<List<VpnNode>> vpnNodes(Ref ref) => ref.watch(nodesRepositoryProvider).list();

/// Nodes grouped by region, for a sectioned list. The API already returns them
/// ordered by `(region, name)`, so a single pass preserves that order.
@riverpod
Future<Map<String, List<VpnNode>>> vpnNodesByRegion(Ref ref) async {
  final nodes = await ref.watch(vpnNodesProvider.future);
  final grouped = <String, List<VpnNode>>{};
  for (final node in nodes) {
    grouped.putIfAbsent(node.region, () => []).add(node);
  }
  return grouped;
}
