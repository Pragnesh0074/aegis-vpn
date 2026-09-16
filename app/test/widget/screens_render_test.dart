import 'package:aegis_vpn/core/theme/app_theme.dart';
import 'package:aegis_vpn/features/auth/presentation/login_screen.dart';
import 'package:aegis_vpn/features/auth/presentation/register_screen.dart';
import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/history/domain/vpn_session_record.dart';
import 'package:aegis_vpn/features/history/presentation/history_screen.dart';
import 'package:aegis_vpn/features/history/presentation/session_recorder.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/devices/presentation/device_config_screen.dart';
import 'package:aegis_vpn/features/home/presentation/connect_screen.dart';
import 'package:aegis_vpn/features/profile/domain/user_profile.dart';
import 'package:aegis_vpn/features/profile/presentation/profile_providers.dart';
import 'package:aegis_vpn/features/profile/presentation/profile_screen.dart';
import 'package:aegis_vpn/features/profile/presentation/widgets/settings_tile.dart';
import 'package:aegis_vpn/features/nodes/domain/vpn_node.dart';
import 'package:aegis_vpn/features/nodes/presentation/locations_screen.dart';
import 'package:aegis_vpn/features/nodes/presentation/nodes_providers.dart';
import 'package:aegis_vpn/features/nodes/presentation/selected_node.dart';
import 'package:aegis_vpn/features/splittunnel/domain/installed_app.dart';
import 'package:aegis_vpn/features/splittunnel/presentation/split_tunnel_controller.dart';
import 'package:aegis_vpn/features/splittunnel/presentation/split_tunnel_screen.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:aegis_vpn/features/tunnel/domain/tunnel_status.dart';
import 'package:aegis_vpn/features/tunnel/presentation/tunnel_metrics.dart';
import 'package:aegis_vpn/features/tunnel/presentation/widgets/connect_orb.dart';
import 'package:aegis_vpn/features/whoami/domain/exit_check.dart';
import 'package:aegis_vpn/features/whoami/presentation/exit_check_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

  /// What `/whoami` says before anything is connected: the device's own address,
  /// recognised as belonging to no node.
  final unprotected = ExitCheck(
    ip: '49.36.180.22',
    viaTunnel: false,
    node: null,
    checkedAt: DateTime.utc(2026, 9, 15, 10),
  );

  /// The same call once traffic is going through Frankfurt.
  final viaFrankfurt = ExitCheck(
    ip: '3.71.204.118',
    viaTunnel: true,
    node: const ExitNode(id: 'n-fra', name: 'Frankfurt #1', region: 'de-frankfurt'),
    checkedAt: DateTime.utc(2026, 9, 15, 10),
  );

  /// What every screen test needs before it can draw: a fleet, a place to rank
  /// it from, and an answer from `/whoami`.
  List<Override> fleet({ExitCheck? seenAs}) => [
        vpnNodesProvider.overrideWith((ref) async => nodes),
        // Automatic ranks by the device's time zone, so a test that did not pin
        // one would pick a different country on a machine set to UTC than on one
        // in India. Placed in India, where the live fleet's users are.
        deviceUtcOffsetProvider.overrideWithValue(
          const Duration(hours: 5, minutes: 30),
        ),
        // There is no network here: without this the card would render its
        // "could not check" state on every screen that carries it.
        exitCheckProvider.overrideWith((ref) async => seenAs ?? unprotected),
      ];

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
          overrides: fleet(),
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

        // Automatic with no stored choice, resolved to the node nearest the
        // device rather than the emptiest one in the fleet. Frankfurt is far
        // emptier than either Indian node and must still not win from here.
        expect(find.text('India'), findsOneWidget);
        expect(find.text('AUTO'), findsOneWidget);

        // The one claim on this screen the device does not make about itself.
        expect(find.text('You appear as 49.36.180.22'), findsOneWidget);
        expect(find.textContaining('Your real address'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('locations screen lists countries with flags and load',
          (tester) async {
        await pumpScreen(
          tester,
          const LocationsScreen(),
          overrides: fleet(),
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        expect(find.text('Closest to you'), findsOneWidget);
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
              ...fleet(),
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

      testWidgets('account page carries every setting, and its caveats', (tester) async {
        await pumpScreen(
          tester,
          const ProfileScreen(),
          surfaceSize: entry.value,
          overrides: [
            userProfileProvider.overrideWith(
              (ref) async => UserProfile(
                id: 'u1',
                email: 'someone@example.com',
                createdAt: DateTime.utc(2026),
                deviceCount: 1,
                maxDevices: 5,
                adBlockEnabled: true,
                // No grant, so filtering is not actually in force.
                adBlockEntitled: false,
                adBlockRemaining: Duration.zero,
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();

        // The list virtualises, so a setting below the fold is not built at all
        // and findsNothing would describe the viewport rather than the page.
        //
        // Dragged from the left gutter, by hand. The helpers all start their
        // drag at the centre of the scrollable, and on a small phone the centre
        // line runs through the Switches — which swallow the gesture and toggle
        // instead of scrolling, so the target never arrives and the failure
        // surfaces as a bare "No element".
        Future<void> scrollTo(Finder finder) async {
          for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
            await tester.dragFrom(
              Offset(8, entry.value.height / 2),
              const Offset(0, -220),
            );
            await tester.pumpAndSettle();
          }
          expect(finder, findsWidgets, reason: 'never scrolled into view');
        }

        // The Protection page is gone; every switch it held has to be reachable
        // from here, under a name someone would actually search for.
        expect(find.text('Ad blocker'), findsOneWidget);

        // Filtering is rented, so with no grant there is nothing to switch and
        // the ad is the only way forward. A switch that springs back would be
        // worse than one that will not move.
        final adBlockSwitch = tester.widget<Switch>(
          find.descendant(
            of: find.ancestor(
              of: find.text('Ad blocker'),
              matching: find.byType(SettingsTile),
            ),
            matching: find.byType(Switch),
          ),
        );
        expect(adBlockSwitch.value, isFalse);
        expect(
          adBlockSwitch.onChanged,
          isNull,
          reason: 'nothing to toggle until an ad has bought some time',
        );
        expect(find.text('Watch ad'), findsOneWidget);

        // The caveat that stops the switch promising what DNS cannot do. Short
        // now, but dropping it would make the setting misleading.
        expect(
          find.textContaining('Ads inside YouTube'),
          findsOneWidget,
          reason: 'the limit of DNS filtering has to stay on the setting',
        );

        await scrollTo(find.text('Auto-connect on public Wi-Fi'));
        expect(find.text('Auto-connect on public Wi-Fi'), findsOneWidget);

        await scrollTo(find.text('Reconnect if it drops'));
        expect(find.text('Reconnect if it drops'), findsOneWidget);

        // The honesty this page exists for: an app cannot block traffic on
        // Android, so it must say who can.
        await scrollTo(find.text('Block traffic when VPN is off'));
        expect(
          find.textContaining('only the system can do this'),
          findsOneWidget,
          reason: 'an app must not imply it can block traffic itself',
        );

        await scrollTo(find.text('Quick Settings tile'));
        expect(find.text('Quick Settings tile'), findsOneWidget);

        await scrollTo(find.text('Connection history'));
        expect(find.text('Connection history'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('split tunnel screen lists apps to exclude', (tester) async {
        await pumpScreen(
          tester,
          const SplitTunnelScreen(),
          overrides: [
            installedAppsProvider.overrideWith((ref) async => _apps),
          ],
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        expect(find.text('Example Bank'), findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
        // Nothing ticked yet, so the screen says what the default actually is
        // rather than leaving "split tunnelling" to be guessed at.
        expect(find.textContaining('Every app uses the tunnel'), findsOneWidget);
        // A system app is labelled, not hidden — a carrier's own app is a
        // plausible thing to exclude.
        expect(find.textContaining('· system'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('history screen totals the sessions it lists', (tester) async {
        await pumpScreen(
          tester,
          const HistoryScreen(),
          overrides: [
            sessionHistoryProvider.overrideWith((ref) async => _sessions),
          ],
          surfaceSize: entry.value,
        );
        await tester.pumpAndSettle();

        expect(find.text('Frankfurt #1'), findsOneWidget);
        expect(find.text('Mumbai #1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // sessions
        // The promise that makes a usage log acceptable in a VPN app.
        expect(find.textContaining('Nothing here is sent to the server'), findsOneWidget);
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
        ...fleet(),
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

  testWidgets('the exit check names the country the server saw us from',
      (tester) async {
    await pumpScreen(
      tester,
      const ConnectScreen(),
      overrides: [
        ...fleet(seenAs: viaFrankfurt),
        tunnelStatusStreamProvider.overrideWith((ref) => Stream.value(_handshaking)),
      ],
    );
    await tester.pump();

    expect(find.textContaining('You appear in Germany'), findsOneWidget);
    expect(find.text('3.71.204.118 · Frankfurt #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tunnel that is up but not carrying the traffic is called out',
      (tester) async {
    // The failure every other indicator on this screen would miss: the
    // interface is up, the peer is answering, and the request still reached the
    // API from the device's own address.
    await pumpScreen(
      tester,
      const ConnectScreen(),
      overrides: [
        ...fleet(),
        tunnelStatusStreamProvider.overrideWith((ref) => Stream.value(_handshaking)),
      ],
    );
    await tester.pump();

    expect(find.text('Protected'), findsOneWidget);
    expect(find.text('Your traffic is not exiting through Aegis'), findsOneWidget);
    expect(
      find.textContaining('not one of our servers'),
      findsOneWidget,
    );
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
/// Up, and the peer is answering — the state in which a non-fleet exit address
/// means something is wrong rather than simply that nothing is connected.
final _handshaking = TunnelStatus(
  state: TunnelState.connected,
  deviceId: 'd1',
  stats: TunnelStats(
    rxBytes: 4096,
    txBytes: 4096,
    lastHandshake: DateTime.now(),
  ),
);

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

/// Two apps a picker has to draw: one ordinary, one shipped with the device.
const _apps = [
  InstalledApp(package: 'com.bank.example', label: 'Example Bank', isSystem: false),
  InstalledApp(package: 'com.android.chat', label: 'Chat', isSystem: true),
];

final _sessions = [
  VpnSessionRecord(
    startedAt: DateTime.utc(2026, 9, 15, 9),
    endedAt: DateTime.utc(2026, 9, 15, 10),
    rxBytes: 4 * 1024 * 1024,
    txBytes: 512 * 1024,
    nodeName: 'Frankfurt #1',
    region: 'de-frankfurt',
  ),
  VpnSessionRecord(
    startedAt: DateTime.utc(2026, 9, 14, 20),
    endedAt: DateTime.utc(2026, 9, 14, 20, 30),
    rxBytes: 1024,
    txBytes: 1024,
    nodeName: 'Mumbai #1',
    region: 'in-mumbai',
  ),
];
