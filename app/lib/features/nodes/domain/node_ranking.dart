import 'region_geo.dart';
import 'vpn_node.dart';

/// Which node automatic should pick.
///
/// The screen used to label this "Fastest available" while the rule behind it
/// was `selectLeastLoaded()` on the backend — the emptiest node with room. Those
/// are not the same thing and on a two-country fleet they actively disagree: the
/// moment Frankfurt is emptier than Mumbai, every Indian user tapping a button
/// marked "fastest" was sent to Germany.
///
/// ## Why this is estimated rather than measured
///
/// Measuring would be better, and neither obvious way to do it exists here:
///
/// - **Probing the node.** WireGuard does not answer unauthenticated packets —
///   that silence is a design goal, not an oversight — so a UDP probe to
///   `:51820` produces no reply to time. There is no TCP listener to fall back
///   on either: the node agent's port is locked to the API's address by a
///   security group, and opening a peer-control API to the internet to time a
///   round trip would be a bad trade. Measuring for real means adding a public
///   probe listener to every node, which is an ops change, not a client one.
/// - **Geolocating the client's IP server-side.** That needs a GeoIP database on
///   the API, or a third-party lookup — and sending a VPN user's real address to
///   someone else's service to find out where they are is precisely the thing
///   this product exists to avoid.
///
/// So: estimate, from the one locational signal the device already has and
/// nothing had to ask permission for — its time zone offset. That gives a
/// longitude, which is the coordinate that matters at this scale, because the
/// intercontinental hop is what dominates latency between a user and a fleet
/// spread across countries.
///
/// The estimate is coarse and the UI says so. It is compared against country
/// centroids, it ignores latitude entirely, and a traveller whose phone has not
/// picked up the local time zone will be ranked from the wrong place. What it
/// does reliably is stop sending someone in Mumbai to Frankfurt because
/// Frankfurt happens to be emptier, which is the failure it replaced.
abstract final class NodeRanking {
  /// How far apart two nodes have to be before closeness outranks load.
  ///
  /// One hour of longitude. Within a band this wide the distance estimate is not
  /// precise enough to claim one node is nearer than another, so the tie goes to
  /// the emptier one — which keeps the load spreading that automatic did before.
  static const bandDegrees = 15.0;

  /// The device's longitude, inferred from its UTC offset.
  ///
  /// Null for an offset outside the range real time zones occupy (UTC-12 to
  /// UTC+14), which a device with a badly set clock can report. An absent
  /// estimate is handled — it falls back to load — and a wrong one is not, so
  /// this rejects rather than clamps.
  static double? longitudeFor(Duration utcOffset) {
    final hours = utcOffset.inMinutes / 60;
    if (hours < -12 || hours > 14) return null;
    return hours * 15.0;
  }

  /// Degrees between two longitudes the short way round, 0-180.
  ///
  /// Wrapping matters at the date line: a device at +172 and a node at -170 are
  /// 18 degrees apart, not 342.
  static double separation(double a, double b) {
    final delta = (a - b).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }

  /// The node automatic should use, or null when nothing can take a peer.
  ///
  /// Only nodes with capacity are considered — picking a full one would hand the
  /// user a 503 at the moment they tapped connect — and a node whose region does
  /// not parse to a country keeps its place in the list on load alone rather
  /// than being dropped, because an unrecognised region is a naming problem, not
  /// a reason to make a node unreachable.
  static VpnNode? nearest(List<VpnNode> nodes, {Duration? utcOffset}) {
    final candidates = nodes.where((node) => node.available).toList();
    if (candidates.isEmpty) return null;

    final here = utcOffset == null ? null : longitudeFor(utcOffset);
    if (here == null) return _emptiest(candidates);

    final scored = [
      for (final node in candidates) (node: node, band: _band(node, here)),
    ];
    // Every region unparseable: there is no geography to rank by, so this is the
    // old behaviour rather than an arbitrary order.
    if (scored.every((entry) => entry.band == null)) return _emptiest(candidates);

    scored.sort((a, b) {
      final bandA = a.band;
      final bandB = b.band;
      if (bandA != bandB) {
        // A node we cannot place sorts last: guessing it is near would be a
        // guess in the one direction that cannot be checked.
        if (bandA == null) return 1;
        if (bandB == null) return -1;
        return bandA.compareTo(bandB);
      }
      return a.node.load.compareTo(b.node.load);
    });

    return scored.first.node;
  }

  /// Which distance band [node] falls in, or null if its region names no country.
  static int? _band(VpnNode node, double here) {
    final there = RegionGeo.parse(node.region).longitude;
    if (there == null) return null;
    return (separation(here, there) / bandDegrees).floor();
  }

  static VpnNode _emptiest(List<VpnNode> candidates) {
    return candidates.reduce((best, node) => node.load < best.load ? node : best);
  }
}
