import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/vpn_node.dart';

part 'nodes_repository.g.dart';

/// Talks to `backend/src/nodes/nodes.controller.ts`.
class NodesRepository {
  const NodesRepository(this._api);

  final ApiClient _api;

  /// `GET /nodes` — active nodes only, already sorted by region then name.
  ///
  /// Authenticated: the server list is not a public inventory.
  Future<List<VpnNode>> list() async {
    final rows = await _api.getList(ApiEndpoints.nodes);
    return rows.map(VpnNode.fromJson).toList(growable: false);
  }
}

@Riverpod(keepAlive: true)
NodesRepository nodesRepository(Ref ref) => NodesRepository(ref.watch(apiClientProvider));
