import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/nodes_repository.dart';
import '../domain/vpn_location.dart';
import '../domain/vpn_node.dart';

part 'nodes_providers.g.dart';

/// The active node fleet.
///
/// `keepAlive` so the connect screen's location line does not re-fetch the list
/// the locations screen already has.
@Riverpod(keepAlive: true)
Future<List<VpnNode>> vpnNodes(Ref ref) => ref.watch(nodesRepositoryProvider).list();

/// The fleet as countries, which is the only shape the locations screen shows.
///
/// The API returns nodes ordered by `(region, name)`; that ordering is not
/// useful once regions are read as countries, so [VpnLocation.group] re-sorts.
@riverpod
Future<List<VpnLocation>> vpnLocations(Ref ref) async {
  return VpnLocation.group(await ref.watch(vpnNodesProvider.future));
}
