// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exit_check_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the tunnel is not merely up but demonstrably carrying traffic.
///
/// A bool rather than the status itself, because [exitCheck] depends on it and
/// the status stream emits every second with new counters. Watching the status
/// would re-run the check once a second; watching a bool re-runs it only when
/// the answer changes.
///
/// The handshake is part of the condition on purpose. An interface that is up
/// has routes installed but may have exchanged nothing, and asking the server
/// where we are at that instant would report the old address and read as a leak.

@ProviderFor(tunnelCarrying)
final tunnelCarryingProvider = TunnelCarryingProvider._();

/// Whether the tunnel is not merely up but demonstrably carrying traffic.
///
/// A bool rather than the status itself, because [exitCheck] depends on it and
/// the status stream emits every second with new counters. Watching the status
/// would re-run the check once a second; watching a bool re-runs it only when
/// the answer changes.
///
/// The handshake is part of the condition on purpose. An interface that is up
/// has routes installed but may have exchanged nothing, and asking the server
/// where we are at that instant would report the old address and read as a leak.

final class TunnelCarryingProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the tunnel is not merely up but demonstrably carrying traffic.
  ///
  /// A bool rather than the status itself, because [exitCheck] depends on it and
  /// the status stream emits every second with new counters. Watching the status
  /// would re-run the check once a second; watching a bool re-runs it only when
  /// the answer changes.
  ///
  /// The handshake is part of the condition on purpose. An interface that is up
  /// has routes installed but may have exchanged nothing, and asking the server
  /// where we are at that instant would report the old address and read as a leak.
  TunnelCarryingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelCarryingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelCarryingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return tunnelCarrying(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$tunnelCarryingHash() => r'8a93ca9c0d2c4204c9f16a0c25a95daf91a887fc';

/// Where the internet currently thinks this device is.
///
/// Re-checked whenever [tunnelCarrying] flips, which is both transitions worth
/// spending a request on: the tunnel came up and the address should now be the
/// node's, or it went away and the address should be the real one again.

@ProviderFor(exitCheck)
final exitCheckProvider = ExitCheckProvider._();

/// Where the internet currently thinks this device is.
///
/// Re-checked whenever [tunnelCarrying] flips, which is both transitions worth
/// spending a request on: the tunnel came up and the address should now be the
/// node's, or it went away and the address should be the real one again.

final class ExitCheckProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExitCheck>,
          ExitCheck,
          FutureOr<ExitCheck>
        >
    with $FutureModifier<ExitCheck>, $FutureProvider<ExitCheck> {
  /// Where the internet currently thinks this device is.
  ///
  /// Re-checked whenever [tunnelCarrying] flips, which is both transitions worth
  /// spending a request on: the tunnel came up and the address should now be the
  /// node's, or it went away and the address should be the real one again.
  ExitCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exitCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exitCheckHash();

  @$internal
  @override
  $FutureProviderElement<ExitCheck> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ExitCheck> create(Ref ref) {
    return exitCheck(ref);
  }
}

String _$exitCheckHash() => r'a00f2cf09bd0000af2b4ed2532e67fd574a66711';
