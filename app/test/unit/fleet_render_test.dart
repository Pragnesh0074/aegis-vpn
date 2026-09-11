import 'package:aegis_vpn/features/nodes/domain/vpn_location.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real fleet, exactly as `GET /nodes` reports it once Frankfurt is active.
///
/// Pins the two things the locations screen depends on for this deployment: that
/// both regions parse to a named country with a flag, and that tapping a row
/// yields a concrete node id for `POST /devices`.
void main() {
  test('the live fleet renders as two pickable countries', () {
    final groups = VpnLocation.group(const [
      VpnNode(id: '501b27c5', name: 'Mumbai #1', region: 'in-mumbai', load: 0.016, available: true),
      VpnNode(id: 'a0047e7d', name: 'Frankfurt #1', region: 'de-frankfurt', load: 0, available: true),
    ]);

    expect(groups.map((g) => g.name), ['Germany', 'India']);
    expect(groups.map((g) => g.flag), ['\u{1F1E9}\u{1F1EA}', '\u{1F1EE}\u{1F1F3}']);
    expect(groups.map((g) => g.cityLine), ['Frankfurt', 'Mumbai']);
    expect(groups.map((g) => g.preferred.id), ['a0047e7d', '501b27c5']);
  });
}
