import 'package:aegis_vpn/features/nodes/domain/node_ranking.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:flutter_test/flutter_test.dart';

/// What "automatic" resolves to, which used to be the emptiest node in the fleet
/// under a button that said "Fastest available".
VpnNode node(
  String id,
  String region, {
  double load = 0.0,
  bool available = true,
}) {
  return VpnNode(
    id: id,
    name: id,
    region: region,
    load: load,
    available: available,
  );
}

const india = Duration(hours: 5, minutes: 30);
const germany = Duration(hours: 1);

void main() {
  final fleet = [
    node('mumbai', 'in-mumbai', load: 0.6),
    node('frankfurt', 'de-frankfurt', load: 0.02),
  ];

  test('a user in India is not sent to Germany because Germany is emptier', () {
    // The exact failure this replaced: `selectLeastLoaded()` sorts by free
    // slots, so a nearly empty Frankfurt beat a busy Mumbai for every user in
    // the world.
    expect(NodeRanking.nearest(fleet, utcOffset: india)?.id, 'mumbai');
  });

  test('a user in Germany gets Germany', () {
    expect(NodeRanking.nearest(fleet, utcOffset: germany)?.id, 'frankfurt');
  });

  test('load still decides between nodes at a similar distance', () {
    // Two nodes in the same band: the estimate cannot tell them apart, so the
    // emptier one wins and automatic keeps spreading load as it used to.
    final indianFleet = [
      node('mumbai', 'in-mumbai', load: 0.9),
      node('delhi', 'in-delhi', load: 0.1),
    ];

    expect(NodeRanking.nearest(indianFleet, utcOffset: india)?.id, 'delhi');
  });

  test('distance outranks load once the nodes are bands apart', () {
    final loaded = [
      node('mumbai', 'in-mumbai', load: 0.95),
      node('frankfurt', 'de-frankfurt', load: 0.0),
    ];

    expect(NodeRanking.nearest(loaded, utcOffset: india)?.id, 'mumbai');
  });

  test('a full node is never chosen, however close it is', () {
    final full = [
      node('mumbai', 'in-mumbai', load: 1, available: false),
      node('frankfurt', 'de-frankfurt', load: 0.5),
    ];

    expect(NodeRanking.nearest(full, utcOffset: india)?.id, 'frankfurt');
  });

  test('nothing available resolves to nothing', () {
    final full = [node('mumbai', 'in-mumbai', load: 1, available: false)];

    expect(NodeRanking.nearest(full, utcOffset: india), isNull);
  });

  test('a node whose region names no country sorts behind one that does', () {
    // An unreadable region is a naming problem, not a reason to make a node
    // unreachable — but it must not be guessed to be nearby either.
    final mixed = [
      node('unknown', 'ap-southeast-2', load: 0.0),
      node('mumbai', 'in-mumbai', load: 0.8),
    ];

    expect(NodeRanking.nearest(mixed, utcOffset: india)?.id, 'mumbai');
  });

  test('a fleet with no readable region falls back to the emptiest node', () {
    final opaque = [
      node('a', 'ap-southeast-2', load: 0.7),
      node('b', 'us-east-1', load: 0.3),
    ];

    expect(NodeRanking.nearest(opaque, utcOffset: india)?.id, 'b');
  });

  test('no time zone to rank by falls back to the emptiest node', () {
    expect(NodeRanking.nearest(fleet)?.id, 'frankfurt');
  });

  test('an impossible UTC offset is rejected rather than clamped', () {
    // A device with a badly set clock has no location to infer; ranking it from
    // a clamped value would be confidently wrong instead of honestly unknown.
    expect(NodeRanking.longitudeFor(const Duration(hours: 20)), isNull);
    expect(NodeRanking.longitudeFor(const Duration(hours: -13)), isNull);
    expect(NodeRanking.longitudeFor(india), closeTo(82.5, 0.001));
  });

  test('separation wraps the short way round the date line', () {
    expect(NodeRanking.separation(172, -170), closeTo(18, 0.001));
    expect(NodeRanking.separation(-170, 172), closeTo(18, 0.001));
    expect(NodeRanking.separation(10, 10), 0);
  });
}
