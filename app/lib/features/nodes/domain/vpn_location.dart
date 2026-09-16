import 'region_geo.dart';
import 'vpn_node.dart';

/// One country on the locations screen, with the nodes that sit in it.
///
/// The API has no notion of a country — it returns a flat node list keyed by
/// `region` — so this grouping is a client-side view built by [group]. A
/// country with a single node is the common case for a small fleet, and the
/// screen collapses those to one row rather than showing a header over a list
/// of one.
class VpnLocation {
  const VpnLocation({required this.geo, required this.nodes});

  /// The country, parsed from the region of the nodes in this group.
  final RegionGeo geo;

  /// Never empty. Ordered emptiest-first, so the row a user is steered towards
  /// is the one most likely to have room.
  final List<VpnNode> nodes;

  String get name => geo.countryName;
  String? get flag => geo.flag;

  /// True when any node here can still be issued a peer.
  bool get available => nodes.any((node) => node.available);

  /// True when at least one node here is answering the API.
  ///
  /// The difference from [available] is what the row says when it cannot be
  /// picked: a country that is full will free up, and one that is offline is
  /// broken. Telling someone "Full" about a node that has fallen over sends them
  /// to wait for something that is not going to happen.
  bool get healthy => nodes.any((node) => node.healthy);

  /// The emptiest node with capacity, or the emptiest one if all are full.
  /// This is what selecting the row actually picks.
  VpnNode get preferred => nodes.firstWhere(
        (node) => node.available,
        orElse: () => nodes.first,
      );

  /// Load across the country, weighted by nothing — a plain mean is enough for
  /// a bar that only has to say "busy" or "quiet".
  double get load =>
      nodes.fold<double>(0, (sum, node) => sum + node.load) / nodes.length;

  /// A city line, when every node in the country agrees on one. Two nodes in
  /// different cities collapse to a count instead, because naming one of them
  /// would be wrong.
  String? get cityLine {
    final cities = nodes.map((node) => RegionGeo.parse(node.region).city).toSet();
    if (cities.length == 1) return cities.first;
    return '${nodes.length} locations';
  }

  /// Groups a flat node list by country, countries alphabetical and nodes
  /// emptiest-first within each.
  static List<VpnLocation> group(List<VpnNode> nodes) {
    final byCountry = <String, List<VpnNode>>{};
    final geoByCountry = <String, RegionGeo>{};

    for (final node in nodes) {
      final geo = RegionGeo.parse(node.region);
      // Regions the parser could not read are their own group, keyed by the raw
      // string, so two unparsed nodes do not get merged into one fake country.
      final key = geo.countryCode ?? 'raw:${geo.raw}';
      byCountry.putIfAbsent(key, () => []).add(node);
      geoByCountry.putIfAbsent(key, () => geo);
    }

    final groups = [
      for (final entry in byCountry.entries)
        VpnLocation(
          geo: geoByCountry[entry.key]!,
          nodes: entry.value..sort((a, b) => a.load.compareTo(b.load)),
        ),
    ];

    groups.sort((a, b) => a.geo.sortKey.compareTo(b.geo.sortKey));
    return groups;
  }
}
