import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../nodes/presentation/widgets/location_summary_card.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../../tunnel/domain/tunnel_status.dart';
import '../../tunnel/presentation/tunnel_controller.dart';
import '../../tunnel/presentation/tunnel_metrics.dart';
import '../../tunnel/presentation/vpn_session.dart';
import '../../tunnel/presentation/widgets/connect_orb.dart';
import '../../tunnel/presentation/widgets/throughput_panel.dart';
import '../../whoami/presentation/widgets/exit_check_card.dart';

/// The landing screen: one button, what it is doing, and where it goes.
///
/// This replaced a device list as the app's front door. Nothing here mentions
/// WireGuard peers or keypairs — the first tap provisions one through
/// [VpnSession] — because a person opening a VPN app wants to be protected, not
/// to administer a fleet.
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(tunnelStatusStreamProvider).value ?? TunnelStatus.disconnected;
    final provisioning = ref.watch(vpnSessionProvider);
    final command = ref.watch(tunnelControllerProvider);
    final uptime = ref.watch(tunnelUptimeProvider);

    final busy = provisioning.isLoading || command.isLoading;
    final phase = _phaseOf(status, isBusy: busy, upFor: uptime);
    // Provisioning and the channel call are one action to the user, so whichever
    // failed is shown in the same place.
    final failure = provisioning.error ?? command.error;

    return Scaffold(
      body: _Aurora(
        phase: phase,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Scrollable, but stretched to fill a tall screen so the orb
                // sits optically centred instead of pinned under the header.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        const _Header(),
                        SizedBox(height: 12.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatePill(
                              phase: phase,
                              uptime: uptime,
                              isUp: status.state.isUp,
                            ),
                            // Only when the platform actually has it armed, not
                            // when the preference merely says so.
                            if (status.killSwitch) ...[
                              SizedBox(width: 8.w),
                              const _KillSwitchChip(),
                            ],
                          ],
                        ),
                        SizedBox(height: 20.h),
                        ConnectOrb(
                          phase: phase,
                          enabled: !busy && !status.state.isBusy,
                          onTap: () => ref.read(vpnSessionProvider.notifier).toggle(),
                        ),
                        SizedBox(height: 18.h),
                        _Headline(phase: phase),
                        SizedBox(height: 6.h),
                        _Detail(
                          phase: phase,
                          status: status,
                          isProvisioning: provisioning.isLoading,
                        ),
                        if (failure != null) ...[
                          SizedBox(height: 12.h),
                          _Failure(error: failure),
                        ],
                        SizedBox(height: 24.h),
                        ThroughputPanel(isUp: status.state.isUp),
                        SizedBox(height: 12.h),
                        // Directly under the counters, which are the claim this
                        // verifies: bytes moving through an interface is not the
                        // same as traffic leaving the country the app says it
                        // does.
                        const ExitCheckCard(),
                        SizedBox(height: 12.h),
                        LocationSummaryCard(
                          onTap: () => context.go(AppRoutes.locations),
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// How long an interface may be up with no handshake before that is reported
  /// as a fault rather than as still connecting.
  ///
  /// A first handshake normally lands in well under a second. WireGuard retries
  /// an unanswered one about every five seconds, so ten covers two attempts:
  /// long enough that a healthy connection is never accused of failing, short
  /// enough that a genuinely dead peer is not dressed up as progress.
  static const _handshakeGrace = Duration(seconds: 10);

  /// Collapses the tunnel state and the in-flight command into the one thing the
  /// screen draws.
  ///
  /// Two overrides, both covering a moment when the raw state would mislead:
  ///
  /// Provisioning happens before the interface is requested, so the platform
  /// still reports `disconnected` while the app is very much connecting.
  /// Without [isBusy] the orb would sit idle through the slowest part of the
  /// flow.
  ///
  /// And an interface that has just come up has not handshaked yet — that is
  /// the handshake being in flight, not a failure. [upFor] holds the alarming
  /// reading back until the grace window has passed.
  static OrbPhase _phaseOf(
    TunnelStatus status, {
    required bool isBusy,
    required Duration upFor,
  }) {
    return switch (status.state) {
      TunnelState.connected when status.stats.isPeerResponding => OrbPhase.protected,
      TunnelState.connected when upFor < _handshakeGrace => OrbPhase.connecting,
      TunnelState.connected => OrbPhase.unverified,
      TunnelState.connecting => OrbPhase.connecting,
      TunnelState.disconnecting => OrbPhase.disconnecting,
      TunnelState.disconnected => isBusy ? OrbPhase.connecting : OrbPhase.idle,
    };
  }
}

/// A wash of colour behind the orb, tinted by state.
///
/// Static gradients rather than an animated field. A perpetually animating
/// background would keep a frame scheduled forever, which costs battery on a
/// screen people leave open and makes `pumpAndSettle` never return in tests.
class _Aurora extends StatelessWidget {
  const _Aurora({required this.phase, required this.child});

  final OrbPhase phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = switch (phase) {
      OrbPhase.protected => AppColors.accent,
      OrbPhase.unverified => AppColors.warn,
      OrbPhase.connecting || OrbPhase.disconnecting => AppColors.accent,
      OrbPhase.idle => AppColors.aurora,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          // Centred on the orb rather than the screen, so the glow reads as
          // coming from the button.
          center: const Alignment(0, -0.28),
          radius: 1.0,
          colors: [
            tint.withValues(alpha: phase.isUp ? 0.16 : 0.09),
            AppColors.bg,
          ],
          stops: const [0.0, 0.72],
        ),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: Row(
        children: [
          Icon(Icons.shield_moon_outlined, size: 20.r, color: AppColors.accent),
          SizedBox(width: 8.w),
          Text(
            'AEGIS',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.2,
              color: AppColors.textHigh,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// The session clock while up, and a dimmed placeholder while not.
///
/// Kept in the layout at all times so the orb does not shift up and down by the
/// height of a pill every time the tunnel changes state.
class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.phase,
    required this.uptime,
    required this.isUp,
  });

  final OrbPhase phase;
  final Duration uptime;

  /// The interface's own state, which leads the phase during the handshake
  /// grace window — the clock should start when the tunnel comes up, not when
  /// the first handshake confirms it.
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final showClock = isUp;
    final tint = phase == OrbPhase.unverified ? AppColors.warn : AppColors.accent;

    return AnimatedOpacity(
      opacity: showClock ? 1 : 0.35,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: showClock ? tint.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(
            color: showClock ? tint.withValues(alpha: 0.4) : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showClock ? Icons.timer_outlined : Icons.lock_open_rounded,
              size: 13.r,
              color: showClock ? tint : AppColors.textMuted,
            ),
            SizedBox(width: 7.w),
            Text(
              showClock ? Format.clock(uptime) : 'Not connected',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: showClock ? tint : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the platform will rebuild a dropped tunnel.
///
/// Deliberately says "auto-reconnect" rather than "protected": it does not block
/// traffic while the tunnel is down, and a shield-shaped badge next to
/// "Not protected" would imply otherwise.
class _KillSwitchChip extends StatelessWidget {
  const _KillSwitchChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.autorenew, size: 12.r, color: AppColors.textMuted),
          SizedBox(width: 6.w),
          Text(
            'Auto-reconnect',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.phase});

  final OrbPhase phase;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (phase) {
      OrbPhase.protected => ('Protected', AppColors.accent),
      // Never "Connected" on its own. The interface is up and carrying routes,
      // but nothing has come back from the peer, and telling someone they are
      // protected when their traffic may be going nowhere is the one lie this
      // screen must not tell.
      OrbPhase.unverified => ('Not verified', AppColors.warn),
      OrbPhase.connecting => ('Connecting', AppColors.textHigh),
      OrbPhase.disconnecting => ('Disconnecting', AppColors.textHigh),
      OrbPhase.idle => ('Not protected', AppColors.textHigh),
    };

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.phase,
    required this.status,
    required this.isProvisioning,
  });

  final OrbPhase phase;
  final TunnelStatus status;
  final bool isProvisioning;

  @override
  Widget build(BuildContext context) {
    final text = switch (phase) {
      OrbPhase.protected =>
        'Handshake ${Format.lastSeen(status.stats.lastHandshake).toLowerCase()}',
      OrbPhase.unverified =>
        'The interface is up, but the server has not replied yet',
      // Up already, inside the grace window: the tunnel exists and is waiting
      // on the peer's first reply.
      OrbPhase.connecting when status.state.isUp =>
        'Completing the handshake with the server',
      // The first connect on a new phone registers a key before it can bring
      // anything up, and that is the slow step worth naming.
      OrbPhase.connecting when isProvisioning => 'Setting up this device',
      OrbPhase.connecting => 'Waiting for the system VPN permission',
      OrbPhase.disconnecting => 'Tearing down the interface',
      OrbPhase.idle => 'Your traffic is not being tunnelled',
    };

    // A floor, not a fixed height. Reserving two lines keeps the orb from
    // hopping as the text changes length between states, but these strings wrap
    // to three lines on a narrow phone and a hard height would clip them.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 34.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted, height: 1.3),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17.r, color: AppColors.danger),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _message(error),
              style: TextStyle(fontSize: 12.5.sp, color: AppColors.textHigh, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// The two failures a person can actually act on get their own wording; the
  /// rest fall through to the app-wide translation.
  static String _message(Object error) {
    if (error is TunnelException) {
      if (error.isPermissionDenied) {
        return 'Android needs your permission to create a VPN connection. '
            'Tap connect again and allow it.';
      }
      // The prompt never appeared, so "tap again and allow it" would send
      // someone hunting for a dialog that will not come. The platform message
      // names the actual blocker.
      return error.message;
    }
    // A 409 here means the account still holds a peer that could not be
    // released — connecting revokes the previous one first, and a node that was
    // unreachable at that moment leaves the old row in place and the cap full.
    // It used to send people to Account > Devices; there is no such screen now,
    // and pointing at one would be worse than admitting there is nothing to do
    // but retry.
    if (error is ApiException && error.isConflict) {
      return 'An earlier connection on your account could not be released, so a '
          'new one cannot be set up. Try again in a moment.';
    }
    return describeError(error);
  }
}
