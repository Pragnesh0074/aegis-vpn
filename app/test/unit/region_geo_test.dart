import 'package:aegis_vpn/features/nodes/domain/region_geo.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_location.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:flutter_test/flutter_test.dart';

VpnNode node(String id, String region, {double load = 0.1, bool available = true}) {
  return VpnNode(
    id: id,
    name: id.toUpperCase(),
    region: region,
    load: load,
    available: available,
  );
}

void main() {
  group('RegionGeo.parse', () {
    test('reads the backend\'s <iso2>-<city> convention', () {
      // The shape `SEED_NODE_REGION` defaults to in backend/prisma/seed.ts.
      final geo = RegionGeo.parse('in-mumbai');

      expect(geo.countryCode, 'IN');
      expect(geo.countryName, 'India');
      expect(geo.city, 'Mumbai');
      // Regional indicators for I and N, which is what a platform draws as a flag.
      expect(geo.flag, '\u{1F1EE}\u{1F1F3}');
    });

    test('title-cases a multi-word city', () {
      expect(RegionGeo.parse('us-new-york').city, 'New York');
      expect(RegionGeo.parse('us-new-york').countryName, 'United States');
    });

    test('refuses to invent a country for a cloud region code', () {
      // An operator may seed anything. `ap-south-1` has a two-letter prefix but
      // AP is not a country, and rendering a flag of two blank letters would be
      // worse than rendering none.
      final geo = RegionGeo.parse('ap-south-1');

      expect(geo.countryCode, isNull);
      expect(geo.flag, isNull);
      // Still identifiable rather than blank.
      expect(geo.countryName, 'ap-south-1');
    });

    test('handles a region with no city segment and one with no dash', () {
      expect(RegionGeo.parse('de-').countryCode, 'DE');
      expect(RegionGeo.parse('de-').city, isNull);

      expect(RegionGeo.parse('frankfurt').countryCode, isNull);
      expect(RegionGeo.parse('frankfurt').countryName, 'frankfurt');
    });

    test('sorts named countries ahead of regions it could not read', () {
      final named = RegionGeo.parse('in-mumbai').sortKey;
      final unnamed = RegionGeo.parse('ap-south-1').sortKey;

      expect(named.compareTo(unnamed), isNegative);
    });
  });

  group('VpnLocation.group', () {
    test('groups nodes by country, alphabetically, emptiest node first', () {
      final groups = VpnLocation.group([
        node('a', 'in-mumbai', load: 0.8),
        node('b', 'de-frankfurt', load: 0.2),
        node('c', 'in-delhi', load: 0.3),
      ]);

      expect(groups.map((g) => g.name), ['Germany', 'India']);

      final india = groups.last;
      expect(india.nodes.map((n) => n.id), ['c', 'a']);
      // Two cities in one country cannot be named by one of them.
      expect(india.cityLine, '2 locations');
      expect(india.load, closeTo(0.55, 1e-9));
    });

    test('names the city when a country has only one', () {
      final groups = VpnLocation.group([node('a', 'in-mumbai')]);

      expect(groups.single.cityLine, 'Mumbai');
      expect(groups.single.flag, isNotNull);
    });

    test('keeps unparsed regions as separate groups', () {
      // Two nodes the parser cannot read must not be merged into one country
      // just because neither has a code.
      final groups = VpnLocation.group([
        node('a', 'ap-south-1'),
        node('b', 'eu-west-2'),
      ]);

      expect(groups.length, 2);
      expect(groups.every((g) => g.flag == null), isTrue);
    });

    test('prefers a node with capacity, and reports the country full without one',
        () {
      final full = VpnLocation.group([
        node('a', 'in-mumbai', load: 0.1, available: false),
        node('b', 'in-delhi', load: 0.9, available: false),
      ]).single;

      expect(full.available, isFalse);
      // Nothing selectable, so `preferred` falls back rather than throwing.
      expect(full.preferred.id, 'a');

      final partial = VpnLocation.group([
        node('a', 'in-mumbai', load: 0.1, available: false),
        node('b', 'in-delhi', load: 0.9, available: true),
      ]).single;

      expect(partial.available, isTrue);
      // The emptiest node is full, so the choice has to be the other one.
      expect(partial.preferred.id, 'b');
    });
  });
}
