import 'package:aegis_vpn/core/theme/app_theme.dart';
import 'package:aegis_vpn/features/auth/presentation/login_screen.dart';
import 'package:aegis_vpn/features/auth/presentation/register_screen.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/devices/presentation/device_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// Renders the screens that do not need a live API, at two very different sizes.
///
/// The point is not pixel assertions — it is that ScreenUtil is initialised, that
/// no `.w`/`.sp` call throws, and that nothing overflows on a small phone.
void main() {
  final config = DeviceConfig(
    deviceId: 'a3f1c8de-0000-4000-8000-000000000001',
    name: 'Pixel 9',
    platform: 'android',
    createdAt: DateTime.utc(2026, 9, 10, 12),
    tunnelIp: '10.8.0.4/32',
    dns: '10.8.0.1',
    mtu: 1420,
    node: const DeviceNode(id: 'n1', name: 'Frankfurt 1', region: 'eu-central'),
    peer: const PeerConfig(
      publicKey: 'kP1LqYyZ9Xn2vB7cD4eF6gH8jK0mN3pQ5rS7tU9wX1Y=',
      endpoint: '203.0.113.10:51820',
      allowedIps: '0.0.0.0/0, ::/0',
      persistentKeepalive: 25,
    ),
  );

  // A small phone and a large one. An overflow on either fails the test, because
  // the test binding surfaces render errors as exceptions.
  const sizes = {
    'small phone': Size(320, 640),
    'large phone': Size(430, 932),
  };

  for (final entry in sizes.entries) {
    group('at ${entry.key}', () {
      testWidgets('login screen renders', (tester) async {
        await pumpScreen(tester, const LoginScreen(), surfaceSize: entry.value);
        expect(find.text('Sign in'), findsWidgets);
        expect(find.text('Create an account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('register screen renders with the password rule', (tester) async {
        await pumpScreen(tester, const RegisterScreen(), surfaceSize: entry.value);
        expect(find.textContaining('At least 10 characters'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('device config shows every field the API returned', (tester) async {
        await pumpScreen(
          tester,
          DeviceConfigScreen(config: config, isNew: true),
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        // The tunnel is only ever reported by the platform, and no platform is
        // answering in a widget test, so the card must fall back to the state that
        // claims no protection.
        expect(find.text('Not connected'), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);

        expect(find.text('10.8.0.4/32'), findsOneWidget);
        expect(find.text('1420'), findsOneWidget);

        // No private key in the fake keystore, so the screen must say so rather
        // than render a config that cannot work.
        expect(find.text('Not on this device'), findsOneWidget);

        // The peer section starts below the fold on a small phone now that the
        // connect card is above it. Scroll rather than assert on whatever fits.
        Future<void> scrollTo(Finder finder) => tester.scrollUntilVisible(
              finder,
              200,
              scrollable: find.byType(Scrollable).first,
            );

        await scrollTo(find.text('203.0.113.10:51820'));
        expect(find.text('203.0.113.10:51820'), findsOneWidget);
        expect(find.text(config.peer.publicKey), findsOneWidget);

        await scrollTo(find.text('0.0.0.0/0, ::/0'));
        expect(find.text('0.0.0.0/0, ::/0'), findsOneWidget);
        expect(find.text('25s'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('login form rejects a malformed email before any request', (tester) async {
    await pumpScreen(tester, const LoginScreen());

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('spacing scales with the design size', (tester) async {
    late double medium;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) {
          medium = Gap.md.height!;
          return const SizedBox.shrink();
        },
      ),
      surfaceSize: const Size(750, 1624), // exactly 2x the 375-wide design
    );

    // 16 logical pixels at the design width, doubled here.
    expect(medium, closeTo(32, 0.5));
  });
}
