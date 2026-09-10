// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_key_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceKeyStore)
final deviceKeyStoreProvider = DeviceKeyStoreProvider._();

final class DeviceKeyStoreProvider
    extends $FunctionalProvider<DeviceKeyStore, DeviceKeyStore, DeviceKeyStore>
    with $Provider<DeviceKeyStore> {
  DeviceKeyStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceKeyStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceKeyStoreHash();

  @$internal
  @override
  $ProviderElement<DeviceKeyStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceKeyStore create(Ref ref) {
    return deviceKeyStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceKeyStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceKeyStore>(value),
    );
  }
}

String _$deviceKeyStoreHash() => r'e37b1e50960ff0dde51af8c46fa6844bae909067';
