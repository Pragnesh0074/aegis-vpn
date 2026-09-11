import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';

/// What the orb is drawing. Not the same set as `TunnelState`: the orb has to
/// distinguish an interface that is up and answering from one that is up and
/// silent, because those are the two cases a person most needs told apart and
/// the tunnel state alone cannot say which is which.
enum OrbPhase {
  idle,
  connecting,

  /// Up, and the peer handshaked recently. The only phase that claims safety.
  protected,

  /// Up, but nothing is coming back. Amber, never green.
  unverified,
  disconnecting;

  bool get isBusy => this == connecting || this == disconnecting;
  bool get isUp => this == protected || this == unverified;
}

/// The connect button: a tappable core inside animated rings.
///
/// Animation is driven by two controllers that only run when the phase needs
/// them — ripples while up, a sweep while busy, nothing at all while idle. That
/// is not only for battery: a controller left repeating forever makes
/// `pumpAndSettle` hang, so an always-on animation would make every widget test
/// that touches this screen time out.
class ConnectOrb extends StatefulWidget {
  const ConnectOrb({
    super.key,
    required this.phase,
    required this.onTap,
    this.enabled = true,
  });

  final OrbPhase phase;

  /// Null-safe by contract: the screen always has something to do on a tap, and
  /// [enabled] is what expresses "not right now".
  final VoidCallback onTap;

  /// False while a command is in flight, so the button cannot fight itself.
  final bool enabled;

  /// The full painted box, rings included.
  static const diameter = 268.0;

  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _ConnectOrbState extends State<ConnectOrb> with TickerProviderStateMixin {
  /// Outward ripples plus the core's breathing, while the tunnel is up.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// The arc that circles the core while connecting or tearing down.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(ConnectOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncAnimations();
  }

  void _syncAnimations() {
    if (widget.phase.isUp) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }

    if (widget.phase.isBusy) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
      _sweep.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _sweep.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.phase) {
        OrbPhase.protected => AppColors.accent,
        OrbPhase.unverified => AppColors.warn,
        OrbPhase.connecting || OrbPhase.disconnecting => AppColors.accent,
        OrbPhase.idle => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final size = ConnectOrb.diameter.r;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: switch (widget.phase) {
        OrbPhase.protected || OrbPhase.unverified => 'Disconnect',
        OrbPhase.connecting => 'Connecting',
        OrbPhase.disconnecting => 'Disconnecting',
        OrbPhase.idle => 'Connect',
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            // Both controllers, so a phase change that swaps which one is
            // running does not need a rebuild to take effect.
            animation: Listenable.merge([_pulse, _sweep]),
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbPainter(
                  accent: accent,
                  pulse: _pulse.value,
                  sweep: _sweep.value,
                  showRipples: widget.phase.isUp,
                  showSweep: widget.phase.isBusy,
                ),
                child: Center(child: _core(accent, size)),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _core(Color accent, double size) {
    // A slow 3% breath while up. Enough to read as alive, small enough not to
    // draw the eye away from the label underneath.
    final breath = widget.phase.isUp
        ? 1 + 0.03 * math.sin(_pulse.value * 2 * math.pi)
        : 1.0;
    final scale = (_pressed ? 0.94 : 1.0) * breath;
    final coreSize = size * 0.58;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        width: coreSize,
        height: coreSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: widget.phase.isUp
                ? [accent.withValues(alpha: 0.34), AppColors.surface]
                : [AppColors.surfaceHigh, AppColors.surface],
            stops: const [0.0, 1.0],
          ),
          border: Border.all(
            color: accent.withValues(alpha: widget.phase.isUp ? 0.85 : 0.35),
            width: 1.6.r,
          ),
          boxShadow: [
            // The glow. Wider and brighter when up, which is most of what makes
            // the connected state readable at a glance across a dark room.
            BoxShadow(
              color: accent.withValues(alpha: widget.phase.isUp ? 0.42 : 0.12),
              blurRadius: widget.phase.isUp ? 46.r : 18.r,
              spreadRadius: widget.phase.isUp ? 2.r : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: coreSize * 0.3,
              color: widget.phase.isUp ? accent : AppColors.textHigh,
            ),
            SizedBox(height: 8.h),
            Text(
              switch (widget.phase) {
                OrbPhase.protected || OrbPhase.unverified => 'TAP TO STOP',
                OrbPhase.connecting => 'STARTING',
                OrbPhase.disconnecting => 'STOPPING',
                OrbPhase.idle => 'TAP TO CONNECT',
              },
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: widget.phase.isUp
                    ? accent.withValues(alpha: 0.9)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rings, ripples and the busy sweep. The core itself is a real widget so it can
/// hold text and take taps; only the decoration around it is painted.
class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.accent,
    required this.pulse,
    required this.sweep,
    required this.showRipples,
    required this.showSweep,
  });

  final Color accent;
  final double pulse;
  final double sweep;
  final bool showRipples;
  final bool showSweep;

  /// Three ripples, evenly offset, so one is always mid-flight.
  static const _rippleCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final coreRadius = size.width * 0.29;

    // The static track the core sits in, so the orb has a defined edge even
    // when nothing is animating.
    canvas.drawCircle(
      center,
      coreRadius + (outer - coreRadius) * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.outline,
    );

    if (showRipples) {
      for (var i = 0; i < _rippleCount; i++) {
        final progress = (pulse + i / _rippleCount) % 1.0;
        final radius = coreRadius + (outer - coreRadius) * progress;
        // Fade with the square of the remaining distance: a linear fade leaves
        // the ring visibly clipping at the edge of the box.
        final alpha = (1 - progress) * (1 - progress) * 0.5;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = accent.withValues(alpha: alpha),
        );
      }
    }

    if (showSweep) {
      final radius = coreRadius + (outer - coreRadius) * 0.42;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        sweep * 2 * math.pi,
        math.pi / 2.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi / 2.4,
            colors: [accent.withValues(alpha: 0), accent],
            transform: GradientRotation(sweep * 2 * math.pi),
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) {
    return old.pulse != pulse ||
        old.sweep != sweep ||
        old.accent != accent ||
        old.showRipples != showRipples ||
        old.showSweep != showSweep;
  }
}
