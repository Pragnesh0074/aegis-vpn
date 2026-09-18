import 'package:aegis_vpn/features/autoconnect/domain/auto_connect_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('remembering joined networks', () {
    test('records newest first without duplicates', () {
      var s = AutoConnectSettings.off
          .remember('Home')
          .remember('Cafe')
          .remember('Home');

      expect(s.seen, ['Home', 'Cafe']);
    });

    // A phone that has been to a lot of cafés must not grow this list forever.
    test('is bounded', () {
      var s = AutoConnectSettings.off;
      for (var i = 0; i < AutoConnectSettings.maxSeen + 10; i++) {
        s = s.remember('net-$i');
      }
      expect(s.seen, hasLength(AutoConnectSettings.maxSeen));
      // Newest kept, oldest dropped.
      expect(s.seen.first, 'net-${AutoConnectSettings.maxSeen + 9}');
      expect(s.seen, isNot(contains('net-0')));
    });

    test('case-insensitive, like the platform match', () {
      final s = AutoConnectSettings.off.remember('Home').remember('HOME');
      expect(s.seen, hasLength(1));
    });
  });

  group('untrustedSeen', () {
    test('offers only what is not already trusted', () {
      final s = AutoConnectSettings.off
          .copyWith(trusted: ['Home'])
          .remember('Home')
          .remember('Cafe');

      expect(s.untrustedSeen, ['Cafe']);
    });

    // The list exists to be acted on; once everything is trusted there is
    // nothing to show, and the section should disappear rather than sit empty.
    test('is empty when everything joined is trusted', () {
      final s = AutoConnectSettings.off
          .copyWith(trusted: ['Home', 'Cafe'])
          .remember('Home')
          .remember('Cafe');

      expect(s.untrustedSeen, isEmpty);
    });
  });
}
