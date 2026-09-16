import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/node_selection_store.dart';
import '../domain/node_ranking.dart';
import '../domain/region_geo.dart';
import '../domain/vpn_node.dart';
import 'nodes_providers.dart';

part 'selected_node.g.dart';

/// The node the user chose, or null for automatic.
///
/// Hydrated from the keystore, so the choice survives a restart. Automatic is a
/// real state rather than a stand-in for "not loaded yet": it means the app
/// omits `nodeId` from `POST /devices` and lets the backend pick.
@Riverpod(keepAlive: true)
class SelectedNodeId extends _$SelectedNodeId {
  @override
  Future<String?> build() => ref.watch(nodeSelectionStoreProvider).read();

  /// [nodeId] null selects automatic.
  Future<void> select(String? nodeId) async {
    final store = ref.read(nodeSelectionStoreProvider);
    if (nodeId == null) {
      await store.clear();
    } else {
      await store.write(nodeId);
    }
    state = AsyncData(nodeId);
  }
}

/// The chosen node resolved against the live fleet, or null on automatic.
///
/// Resolving rather than trusting the stored id matters: a node can be
/// deactivated or removed between runs, and a dangling id would otherwise show
/// as a location that no longer exists and fail at `POST /devices` with a 404.
/// An unresolvable id reads as automatic, which still connects.
@riverpod
Future<VpnNode?> selectedNode(Ref ref) async {
  final id = await ref.watch(selectedNodeIdProvider.future);
  if (id == null) return null;

  final nodes = await ref.watch(vpnNodesProvider.future);
  for (final node in nodes) {
    if (node.id == id) return node;
  }
  return null;
}

/// The device's offset from UTC, which is all the location this app asks for.
///
/// A provider rather than a direct `DateTime.now()` call so a test can place the
/// device somewhere without moving the machine's clock. See [NodeRanking] for
/// why a time zone is the signal being used.
@Riverpod(keepAlive: true)
Duration deviceUtcOffset(Ref ref) => DateTime.now().timeZoneOffset;

/// What automatic resolves to: the nearest node with capacity.
///
/// No longer a prediction of what the backend would do. The client picks, and
/// sends that node id on `POST /devices` — see `VpnSession._ensureDevice`. The
/// backend's `selectLeastLoaded()` remains the fallback for a request that names
/// no node, which now happens only when there is nothing to rank by.
///
/// The client is the right place for this: it is the only party that knows where
/// the device is, and it already had to compute this answer to put a country on
/// the connect screen. Leaving the decision on the server meant the screen
/// predicted one node while the server chose another, and the two disagreed
/// exactly when the fleet was busy.
@riverpod
Future<VpnNode?> nearestNode(Ref ref) async {
  final nodes = await ref.watch(vpnNodesProvider.future);
  return NodeRanking.nearest(nodes, utcOffset: ref.watch(deviceUtcOffsetProvider));
}

/// The location line the connect screen headlines, resolved for either mode.
///
/// On automatic this reports the node automatic will pick, flagged as such, so
/// the screen never has to show a bare "Automatic" with no country attached.
@riverpod
Future<LocationChoice> locationChoice(Ref ref) async {
  final chosen = await ref.watch(selectedNodeProvider.future);
  if (chosen != null) {
    return LocationChoice(node: chosen, isAutomatic: false);
  }
  return LocationChoice(
    node: await ref.watch(nearestNodeProvider.future),
    isAutomatic: true,
  );
}

/// A resolved location: which node, and whether the user picked it.
class LocationChoice {
  const LocationChoice({required this.node, required this.isAutomatic});

  /// Null when the fleet is empty or entirely full.
  final VpnNode? node;

  /// True when the backend, not the user, decides the node.
  final bool isAutomatic;

  RegionGeo? get geo => node == null ? null : RegionGeo.parse(node!.region);
}
