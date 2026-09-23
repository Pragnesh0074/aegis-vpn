// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_metrics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ThroughputMeter)
final throughputMeterProvider = ThroughputMeterProvider._();

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
final class ThroughputMeterProvider
    extends $NotifierProvider<ThroughputMeter, Throughput> {
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
  ThroughputMeterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'throughputMeterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$throughputMeterHash();

  @$internal
  @override
  ThroughputMeter create() => ThroughputMeter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Throughput value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Throughput>(value),
    );
  }
}

String _$throughputMeterHash() => r'31357301bba9c1f32ac5219380af5b0cb090fd54';

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

abstract class _$ThroughputMeter extends $Notifier<Throughput> {
  Throughput build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Throughput, Throughput>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Throughput, Throughput>,
              Throughput,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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

@ProviderFor(TunnelUptime)
final tunnelUptimeProvider = TunnelUptimeProvider._();

/// How long the tunnel has been up, ticking once a second.
///
/// Timed from when *this app* saw the interface come up, which is the only start
/// time available: nothing in the platform layer records one, and `wg` does not
/// either. So a tunnel that survived the app being killed shows a duration
/// starting from when the app came back, not from the real connect. That is the
/// same behaviour as WireGuard's own Android client, and it is the reason this
/// is presented as a session timer rather than an uptime.
final class TunnelUptimeProvider
    extends $NotifierProvider<TunnelUptime, Duration> {
  /// How long the tunnel has been up, ticking once a second.
  ///
  /// Timed from when *this app* saw the interface come up, which is the only start
  /// time available: nothing in the platform layer records one, and `wg` does not
  /// either. So a tunnel that survived the app being killed shows a duration
  /// starting from when the app came back, not from the real connect. That is the
  /// same behaviour as WireGuard's own Android client, and it is the reason this
  /// is presented as a session timer rather than an uptime.
  TunnelUptimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelUptimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelUptimeHash();

  @$internal
  @override
  TunnelUptime create() => TunnelUptime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$tunnelUptimeHash() => r'4050b991a75469a6934ffe203679b476f918e716';

/// How long the tunnel has been up, ticking once a second.
///
/// Timed from when *this app* saw the interface come up, which is the only start
/// time available: nothing in the platform layer records one, and `wg` does not
/// either. So a tunnel that survived the app being killed shows a duration
/// starting from when the app came back, not from the real connect. That is the
/// same behaviour as WireGuard's own Android client, and it is the reason this
/// is presented as a session timer rather than an uptime.

abstract class _$TunnelUptime extends $Notifier<Duration> {
  Duration build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Duration, Duration>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Duration, Duration>,
              Duration,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
