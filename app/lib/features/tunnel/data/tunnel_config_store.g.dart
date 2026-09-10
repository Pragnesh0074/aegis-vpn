// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_config_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tunnelConfigStore)
final tunnelConfigStoreProvider = TunnelConfigStoreProvider._();

final class TunnelConfigStoreProvider
    extends
        $FunctionalProvider<
          TunnelConfigStore,
          TunnelConfigStore,
          TunnelConfigStore
        >
    with $Provider<TunnelConfigStore> {
  TunnelConfigStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelConfigStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelConfigStoreHash();

  @$internal
  @override
  $ProviderElement<TunnelConfigStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TunnelConfigStore create(Ref ref) {
    return tunnelConfigStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TunnelConfigStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TunnelConfigStore>(value),
    );
  }
}

String _$tunnelConfigStoreHash() => r'8a18e64ce269c8398a57c7f2effd07b2b0519c14';

/// The cached peer details for a device, or null when this phone did not issue it.
///
/// Backs reopening the config screen from the device list: without a cache hit
/// there is genuinely nothing to show, because the API will not re-issue the peer.

@ProviderFor(cachedDeviceConfig)
final cachedDeviceConfigProvider = CachedDeviceConfigFamily._();

/// The cached peer details for a device, or null when this phone did not issue it.
///
/// Backs reopening the config screen from the device list: without a cache hit
/// there is genuinely nothing to show, because the API will not re-issue the peer.

final class CachedDeviceConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceConfig?>,
          DeviceConfig?,
          FutureOr<DeviceConfig?>
        >
    with $FutureModifier<DeviceConfig?>, $FutureProvider<DeviceConfig?> {
  /// The cached peer details for a device, or null when this phone did not issue it.
  ///
  /// Backs reopening the config screen from the device list: without a cache hit
  /// there is genuinely nothing to show, because the API will not re-issue the peer.
  CachedDeviceConfigProvider._({
    required CachedDeviceConfigFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cachedDeviceConfigProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cachedDeviceConfigHash();

  @override
  String toString() {
    return r'cachedDeviceConfigProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DeviceConfig?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceConfig?> create(Ref ref) {
    final argument = this.argument as String;
    return cachedDeviceConfig(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CachedDeviceConfigProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cachedDeviceConfigHash() =>
    r'fdafc08f9db39df8685ebcd5dcc000d01f3e17e3';

/// The cached peer details for a device, or null when this phone did not issue it.
///
/// Backs reopening the config screen from the device list: without a cache hit
/// there is genuinely nothing to show, because the API will not re-issue the peer.

final class CachedDeviceConfigFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DeviceConfig?>, String> {
  CachedDeviceConfigFamily._()
    : super(
        retry: null,
        name: r'cachedDeviceConfigProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The cached peer details for a device, or null when this phone did not issue it.
  ///
  /// Backs reopening the config screen from the device list: without a cache hit
  /// there is genuinely nothing to show, because the API will not re-issue the peer.

  CachedDeviceConfigProvider call(String deviceId) =>
      CachedDeviceConfigProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'cachedDeviceConfigProvider';
}
