import 'package:aegis_vpn/features/killswitch/data/kill_switch_store.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  group('KillSwitchStore', () {
    test('defaults to off when nothing was ever chosen', () async {
      // Arming it unasked would rebuild tunnels a user deliberately dropped.
      expect(await KillSwitchStore(InMemorySecureStore()).read(), isFalse);
    });

    test('survives a restart, because silently disarming is the worst outcome',
        () async {
      final backing = InMemorySecureStore();
      await KillSwitchStore(backing).write(enabled: true);

      // A fresh store over the same storage stands in for a new process.
      expect(await KillSwitchStore(backing).read(), isTrue);
    });

    test('reads a value it did not write as off rather than throwing', () async {
      final backing = InMemorySecureStore()
        ..values['aegis.tunnel.killSwitch'] = 'garbage';

      expect(await KillSwitchStore(backing).read(), isFalse);
    });
  });

  group('TunnelStatus.killSwitch', () {
    test('comes from the platform, which owns the live flag', () {
      final armed = TunnelStatus.fromJson({
        'state': 'connected',
        'killSwitch': true,
        'rxBytes': 0,
        'txBytes': 0,
      });
      expect(armed.killSwitch, isTrue);
    });

    test('an older native layer that omits it reads as off, not as protected', () {
      // The field must never default to true: the UI draws a badge from it, and
      // claiming a kill switch that is not armed is the one lie to avoid here.
      final legacy = TunnelStatus.fromJson({'state': 'connected'});

      expect(legacy.killSwitch, isFalse);
      expect(TunnelStatus.disconnected.killSwitch, isFalse);
    });
  });
}
