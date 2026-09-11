import 'package:aegis_vpn/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format.rate', () {
    test('reads as a per-second figure in the same units as the totals', () {
      expect(Format.rate(0), '0 B/s');
      // Below a byte a second is not "0.4 B/s" to a person, it is nothing.
      expect(Format.rate(0.4), '0 B/s');
      expect(Format.rate(900), '900 B/s');
      expect(Format.rate(1536), '1.5 KiB/s');
      expect(Format.rate(5 * 1024 * 1024), '5.0 MiB/s');
    });
  });

  group('Format.clock', () {
    test('omits the hour until there is one', () {
      expect(Format.clock(Duration.zero), '00:00');
      expect(Format.clock(const Duration(seconds: 9)), '00:09');
      expect(Format.clock(const Duration(minutes: 7, seconds: 5)), '07:05');
      expect(Format.clock(const Duration(minutes: 90)), '1:30:00');
      expect(
        Format.clock(const Duration(hours: 13, minutes: 4, seconds: 9)),
        '13:04:09',
      );
    });

    test('a negative duration cannot render a negative clock', () {
      // The session clock is a difference of two wall-clock reads, so a device
      // clock adjustment can hand it a negative value.
      expect(Format.clock(const Duration(seconds: -30)), '00:00');
    });
  });
}
