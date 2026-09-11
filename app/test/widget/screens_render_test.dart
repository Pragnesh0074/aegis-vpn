import 'package:aegis_vpn/core/theme/app_theme.dart';
import 'package:aegis_vpn/features/auth/presentation/login_screen.dart';
import 'package:aegis_vpn/features/auth/presentation/register_screen.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/devices/presentation/device_config_screen.dart';
import 'package:aegis_vpn/features/home/presentation/connect_screen.dart';
import 'package:aegis_vpn/features/killswitch/presentation/kill_switch_screen.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:aegis_vpn/features/nodes/presentation/locations_screen.dart';
import 'package:aegis_vpn/features/nodes/presentation/nodes_providers.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:aegis_vpn/features/tunnel/presentation/tunnel_metrics.dart';
import 'package:aegis_vpn/features/tunnel/presentation/widgets/connect_orb.dart';
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

  // A fleet spanning a country the parser knows, a second city in it, and a
  // region it cannot read — the three cases the locations screen has to draw.
  final nodes = [
    const VpnNode(
      id: 'n-mum',
      name: 'Mumbai #1',
      region: 'in-mumbai',
      load: 0.24,
      available: true,
    ),
    const VpnNode(
      id: 'n-del',
      name: 'Delhi #1',
      region: 'in-delhi',
      load: 0.62,
      available: true,
    ),
    const VpnNode(
      id: 'n-fra',
      name: 'Frankfurt #1',
      region: 'de-frankfurt',
      load: 0.05,
      available: true,
    ),
    const VpnNode(
      id: 'n-syd',
      name: 'Sydney #1',
      region: 'ap-southeast-2',
      load: 1.0,
      available: false,
    ),
  ];

  final withNodes = [vpnNodesProvider.overrideWith((ref) async => nodes)];

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

      testWidgets('connect screen offers one button and no way to add a device',
          (tester) async {
        await pumpScreen(
          tester,
          const ConnectScreen(),
          overrides: withNodes,
          surfaceSize: entry.value,
        );
        // Settling at all is the assertion that matters most here: the orb's
        // ripple and sweep controllers must be stopped while idle, and a
        // repeating one would make this hang rather than fail.
        await tester.pumpAndSettle();

        // No platform answers the tunnel channel in a widget test, so the
        // screen must fall back to the state that claims no protection.
        expect(find.text('Not protected'), findsOneWidget);
        expect(find.text('TAP TO CONNECT'), findsOneWidget);
        expect(find.byType(ConnectOrb), findsOneWidget);

        // The add-device flow is gone: connecting provisions the peer.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.textContaining('Add device'), findsNothing);

        // Bandwidth is on the front screen, zeroed rather than hidden while down.
        expect(find.text('Download'), findsOneWidget);
        expect(find.text('Upload'), findsOneWidget);
        expect(find.text('0 B/s'), findsNWidgets(2));

        // No kill switch reported by the platform, so no badge claiming one.
        expect(find.text('Auto-reconnect'), findsNothing);

        // Automatic with no stored choice, resolved to the emptiest node so the
        // card names a country rather than just saying "Automatic".
        expect(find.text('Germany'), findsOneWidget);
        expect(find.text('AUTO'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('locations screen lists countries with flags and load',
          (tester) async {
        await pumpScreen(
          tester,
          const LocationsScreen(),
          overrides: withNodes,
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        expect(find.text('Fastest available'), findsOneWidget);
        // Alphabetical by country, and the two Indian nodes collapse to one row.
        expect(find.text('Germany'), findsOneWidget);
        expect(find.text('India'), findsOneWidget);
        expect(find.text('2 locations'), findsOneWidget);

        // A region the parser cannot read still renders, under its raw string
        // rather than a made-up country.
        expect(find.text('ap-southeast-2'), findsOneWidget);
        expect(find.text('Full'), findsOneWidget);

        // Flags come from regional-indicator pairs, not an asset bundle.
        expect(find.text('\u{1F1E9}\u{1F1EA}'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      // The states a person only sees with a live tunnel. Driven by overriding
      // the platform status stream, which is the app's single source of truth
      // for whether traffic is being carried.
      for (final scenario in _liveStates) {
        testWidgets('connect screen renders while ${scenario.name}', (tester) async {
          await pumpScreen(
            tester,
            const ConnectScreen(),
            overrides: [
              ...withNodes,
              tunnelStatusStreamProvider.overrideWith(
                (ref) => Stream.value(scenario.status),
              ),
            ],
            surfaceSize: entry.value,
          );
          // Not `pumpAndSettle`: the orb's ripples repeat for as long as the
          // tunnel is up, so settling would never return. Pumping a fixed
          // window is what proves the animation runs without throwing.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 600));

          expect(find.text(scenario.headline), findsOneWidget);
          expect(find.textContaining(scenario.detail), findsOneWidget);
          if (scenario.extraText case final extra?) {
            expect(find.text(extra), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('kill switch screen says what it does not cover', (tester) async {
        await pumpScreen(
          tester,
          const KillSwitchScreen(),
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        expect(find.text('Rebuild the tunnel if it drops'), findsOneWidget);
        // Defaults to off, and the stubbed platform reports it disarmed.
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

        // The honesty this screen exists for: an app cannot block traffic on
        // Android, so the page must say who can. Below the fold on a small
        // phone, so scroll rather than assert on whatever happens to fit.
        Future<void> scrollTo(Finder finder) => tester.scrollUntilVisible(
              finder,
              300,
              scrollable: find.byType(Scrollable).first,
            );

        await scrollTo(find.textContaining('Only Android can stop traffic'));
        expect(find.text('Block all traffic without a VPN'), findsOneWidget);
        expect(find.textContaining('Only Android can stop traffic'), findsOneWidget);

        await scrollTo(find.text('While disconnected'));
        expect(find.text('While disconnected'), findsOneWidget);
        expect(
          find.textContaining('Traffic uses your normal connection'),
          findsOneWidget,
        );

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

  testWidgets('an interface that never handshakes stops claiming to be connecting',
      (tester) async {
    await pumpScreen(
      tester,
      const ConnectScreen(),
      overrides: [
        vpnNodesProvider.overrideWith((ref) async => nodes),
        tunnelStatusStreamProvider.overrideWith((ref) => Stream.value(_noHandshakeYet)),
        // The uptime notifier times from wall clock, not from its own ticks, so
        // that it keeps counting while the app is backgrounded and its timer is
        // throttled. `pump` cannot advance that, so the elapsed time is supplied
        // directly instead.
        tunnelUptimeProvider.overrideWith(
          () => _FixedUptime(const Duration(seconds: 30)),
        ),
      ],
    );
    await tester.pump();

    // Thirty seconds of an up interface with nothing coming back is a fault,
    // and the screen has to say so rather than spin forever.
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.textContaining('has not replied'), findsOneWidget);
    // Never "Protected": nothing has ever been received from the peer.
    expect(find.text('Protected'), findsNothing);
    // The session clock still runs, because the interface really is up.
    expect(find.text('00:30'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

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

/// Reports a fixed session length, standing in for a tunnel that has been up
/// for a while. Subclassing the real notifier skips its `build`, and with it the
/// stream subscription and the periodic timer that a test cannot drive.
class _FixedUptime extends TunnelUptime {
  _FixedUptime(this.value);

  final Duration value;

  @override
  Duration build() => value;
}

/// One tunnel state and what the connect screen must say about it.
class _LiveState {
  const _LiveState({
    required this.name,
    required this.status,
    required this.headline,
    required this.detail,
    this.extraText,
  });

  final String name;
  final TunnelStatus status;
  final String headline;

  /// A substring, because the handshake line carries a relative time.
  final String detail;

  /// Anything else that must appear for this state.
  final String? extraText;
}

/// Interface up, nothing ever received from the peer. The case a green badge
/// would lie about: a blocked UDP port, a stale endpoint, or a peer revoked
/// server-side all look exactly like this.
const _noHandshakeYet = TunnelStatus(
  state: TunnelState.connected,
  deviceId: 'd1',
  stats: TunnelStats(rxBytes: 0, txBytes: 2048),
);

final _liveStates = [
  _LiveState(
    name: 'connected with the kill switch armed',
    status: TunnelStatus(
      state: TunnelState.connected,
      deviceId: 'd1',
      killSwitch: true,
      stats: TunnelStats(
        rxBytes: 1024,
        txBytes: 1024,
        lastHandshake: DateTime.now(),
      ),
    ),
    headline: 'Protected',
    detail: 'Handshake',
    // Never "protected" wording on the badge: it does not block traffic.
    extraText: 'Auto-reconnect',
  ),
  _LiveState(
    name: 'connected and handshaking',
    status: TunnelStatus(
      state: TunnelState.connected,
      deviceId: 'd1',
      stats: TunnelStats(
        rxBytes: 4 * 1024 * 1024,
        txBytes: 512 * 1024,
        lastHandshake: DateTime.now().subtract(const Duration(seconds: 20)),
      ),
    ),
    headline: 'Protected',
    detail: 'Handshake',
  ),
  const _LiveState(
    name: 'up with the first handshake still in flight',
    // Up with no handshake yet. Inside the grace window this is the handshake
    // being in flight, not a fault, so it must not be dressed as one.
    status: _noHandshakeYet,
    headline: 'Connecting',
    detail: 'Completing the handshake',
  ),
  const _LiveState(
    name: 'waiting on the system VPN consent dialog',
    status: TunnelStatus(state: TunnelState.connecting),
    headline: 'Connecting',
    detail: 'system VPN permission',
  ),
  const _LiveState(
    name: 'tearing the interface down',
    status: TunnelStatus(state: TunnelState.disconnecting),
    headline: 'Disconnecting',
    detail: 'Tearing down',
  ),
];
