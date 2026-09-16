import 'package:aegis_vpn/features/whoami/domain/exit_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the shape of `GET /whoami`, which is the app's only external check on
/// whether its traffic is actually leaving through a node.
void main() {
  test('a tunnelled answer carries the node it was recognised as', () {
    final check = ExitCheck.fromJson(const {
      'ip': '3.71.204.118',
      'viaTunnel': true,
      'node': {'id': 'n2', 'name': 'Frankfurt #1', 'region': 'de-frankfurt'},
      'checkedAt': '2026-09-15T10:00:00.000Z',
    });

    expect(check.ip, '3.71.204.118');
    expect(check.viaTunnel, isTrue);
    expect(check.node!.name, 'Frankfurt #1');
    // The card headlines a country, which comes from the same parser the
    // locations screen uses rather than from a field the API would have to add.
    expect(check.geo!.countryName, 'Germany');
    expect(check.geo!.flag, '\u{1F1E9}\u{1F1EA}');
  });

  test('an unrecognised address carries no node and no country', () {
    final check = ExitCheck.fromJson(const {
      'ip': '49.36.180.22',
      'viaTunnel': false,
      'node': null,
      'checkedAt': '2026-09-15T10:00:00.000Z',
    });

    expect(check.viaTunnel, isFalse);
    expect(check.node, isNull);
    expect(check.geo, isNull);
  });
}
