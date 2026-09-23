import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/tunnel_channel.dart';
import '../../domain/tunnel_status.dart';

part 'tunnel_metrics.g.dart';

/// Current transfer rate in each direction, plus the session totals.
class Throughput {
  const Throughput({
    required this.downBytesPerSecond,
    required this.upBytesPerSecond,
    required this.downBytes,
    required this.upBytes,
  });

  /// Received from the peer — "download" in the UI.
  final double downBytesPerSecond;
  final double upBytesPerSecond;

  final int downBytes;
  final int upBytes;

  static const idle = Throughput(
    downBytesPerSecond: 0,
    upBytesPerSecond: 0,
    downBytes: 0,
    upBytes: 0,
  );
}

/// Turns the native counters into a rate.
///
/// `TunnelBridge` reports cumulative `rxBytes`/`txBytes` once a second while the
/// interface is up, so a rate has to be differenced here. Two details make the
/// number trustworthy:
///
/// A raw one-second delta jitters hard enough to be unreadable — the poll is not
/// evenly spaced and WireGuard's counters move in bursts — so the rate is
/// smoothed with an exponential moving average. It is a display figure, not a
/// measurement.
///
/// A *negative* delta means the interface was rebuilt and the counters restarted
/// from zero, not that traffic flowed backwards. Those samples reset the
/// baseline instead of producing a nonsense spike.
@Riverpod(keepAlive: true)
class ThroughputMeter extends _$ThroughputMeter {
  int? _lastDown;
  int? _lastUp;
  DateTime? _lastAt;

  double _downRate = 0;
  double _upRate = 0;

  /// Weight on the newest sample. 0.4 settles within a couple of seconds while
  /// still smoothing the burstiness out.
  static const _smoothing = 0.4;

  @override
  Throughput build() {
    ref.listen(tunnelStatusStreamProvider, (_, next) {
      final status = next.value;
      if (status == null) return;

      if (!status.state.isUp) {
        _reset();
        state = Throughput.idle;
        return;
      }

      _sample(status.stats);
    });

    return Throughput.idle;
  }

  void _reset() {
    _lastDown = null;
    _lastUp = null;
    _lastAt = null;
    _downRate = 0;
    _upRate = 0;
  }

  void _sample(TunnelStats stats) {
    final now = DateTime.now();
    final lastDown = _lastDown;
    final lastUp = _lastUp;
    final lastAt = _lastAt;

    _lastDown = stats.rxBytes;
    _lastUp = stats.txBytes;
    _lastAt = now;

    // First sample of a session, or the counters went backwards because the
    // interface was rebuilt. Either way there is no interval to divide by yet.
    if (lastDown == null || lastUp == null || lastAt == null) {
      state = _emit(stats);
      return;
    }
    if (stats.rxBytes < lastDown || stats.txBytes < lastUp) {
      _downRate = 0;
      _upRate = 0;
      state = _emit(stats);
      return;
    }

    final seconds = now.difference(lastAt).inMilliseconds / 1000;
    // Two emits in the same millisecond would divide by zero. The native poll
    // is 1s, but a state change can emit out of band right next to one.
    if (seconds <= 0.05) return;

    _downRate = _blend(_downRate, (stats.rxBytes - lastDown) / seconds);
    _upRate = _blend(_upRate, (stats.txBytes - lastUp) / seconds);
    state = _emit(stats);
  }

  double _blend(double previous, double sample) {
    return previous + (sample - previous) * _smoothing;
  }

  Throughput _emit(TunnelStats stats) {
    return Throughput(
      downBytesPerSecond: _downRate,
      upBytesPerSecond: _upRate,
      downBytes: stats.rxBytes,
      upBytes: stats.txBytes,
    );
  }
}

/// How long the tunnel has been up, ticking once a second.
///
/// Timed from when *this app* saw the interface come up, which is the only start
/// time available: nothing in the platform layer records one, and `wg` does not
/// either. So a tunnel that survived the app being killed shows a duration
/// starting from when the app came back, not from the real connect. That is the
/// same behaviour as WireGuard's own Android client, and it is the reason this
/// is presented as a session timer rather than an uptime.
@Riverpod(keepAlive: true)
class TunnelUptime extends _$TunnelUptime {
  DateTime? _since;
  Timer? _ticker;

  @override
  Duration build() {
    ref.listen(tunnelStatusStreamProvider, (_, next) {
      final status = next.value;
      final isUp = status != null && status.state.isUp;

      if (!isUp) {
        _stop();
        state = Duration.zero;
        return;
      }

      // Already timing this session — the 1s stats poll lands here every
      // second and must not restart the clock.
      if (_since != null) return;

      _since = DateTime.now();
      state = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final since = _since;
        if (since == null) return;
        state = DateTime.now().difference(since);
      });
    });

    ref.onDispose(_stop);
    return Duration.zero;
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _since = null;
  }
}
