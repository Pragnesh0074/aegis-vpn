// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tunnelChannel)
final tunnelChannelProvider = TunnelChannelProvider._();

final class TunnelChannelProvider
    extends $FunctionalProvider<TunnelChannel, TunnelChannel, TunnelChannel>
    with $Provider<TunnelChannel> {
  TunnelChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelChannelHash();

  @$internal
  @override
  $ProviderElement<TunnelChannel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TunnelChannel create(Ref ref) {
    return tunnelChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TunnelChannel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TunnelChannel>(value),
    );
  }
}

String _$tunnelChannelHash() => r'b53604976df01ea6248be04d8656513fa36e2815';

/// Platform-pushed status, the single source of truth for whether traffic is
/// actually being tunnelled.

@ProviderFor(tunnelStatusStream)
final tunnelStatusStreamProvider = TunnelStatusStreamProvider._();

/// Platform-pushed status, the single source of truth for whether traffic is
/// actually being tunnelled.

final class TunnelStatusStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<TunnelStatus>,
          TunnelStatus,
          Stream<TunnelStatus>
        >
    with $FutureModifier<TunnelStatus>, $StreamProvider<TunnelStatus> {
  /// Platform-pushed status, the single source of truth for whether traffic is
  /// actually being tunnelled.
  TunnelStatusStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelStatusStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelStatusStreamHash();

  @$internal
  @override
  $StreamProviderElement<TunnelStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TunnelStatus> create(Ref ref) {
    return tunnelStatusStream(ref);
  }
}

String _$tunnelStatusStreamHash() =>
    r'ec9265520c232a7fd8f3f90b94b3509bbc0ad170';
