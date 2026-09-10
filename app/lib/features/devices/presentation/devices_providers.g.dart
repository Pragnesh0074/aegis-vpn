// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /devices` — the account's active peers.

@ProviderFor(devices)
final devicesProvider = DevicesProvider._();

/// `GET /devices` — the account's active peers.

final class DevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Device>>,
          List<Device>,
          FutureOr<List<Device>>
        >
    with $FutureModifier<List<Device>>, $FutureProvider<List<Device>> {
  /// `GET /devices` — the account's active peers.
  DevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicesHash();

  @$internal
  @override
  $FutureProviderElement<List<Device>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Device>> create(Ref ref) {
    return devices(ref);
  }
}

String _$devicesHash() => r'1cd065fc73685f8f584dd5cc25314579ee6bcc51';

/// The private key for one device, or null if this phone does not hold it.
///
/// A device issued on another phone, or one whose key was lost to a reinstall,
/// still appears in `GET /devices` — the server has the public half. There is no
/// way to recover the private key, so the UI has to say so rather than pretend.

@ProviderFor(devicePrivateKey)
final devicePrivateKeyProvider = DevicePrivateKeyFamily._();

/// The private key for one device, or null if this phone does not hold it.
///
/// A device issued on another phone, or one whose key was lost to a reinstall,
/// still appears in `GET /devices` — the server has the public half. There is no
/// way to recover the private key, so the UI has to say so rather than pretend.

final class DevicePrivateKeyProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The private key for one device, or null if this phone does not hold it.
  ///
  /// A device issued on another phone, or one whose key was lost to a reinstall,
  /// still appears in `GET /devices` — the server has the public half. There is no
  /// way to recover the private key, so the UI has to say so rather than pretend.
  DevicePrivateKeyProvider._({
    required DevicePrivateKeyFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'devicePrivateKeyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$devicePrivateKeyHash();

  @override
  String toString() {
    return r'devicePrivateKeyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return devicePrivateKey(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DevicePrivateKeyProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$devicePrivateKeyHash() => r'876ba6c86ea7434aaf1a09f5c8e3965bc194181e';

/// The private key for one device, or null if this phone does not hold it.
///
/// A device issued on another phone, or one whose key was lost to a reinstall,
/// still appears in `GET /devices` — the server has the public half. There is no
/// way to recover the private key, so the UI has to say so rather than pretend.

final class DevicePrivateKeyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  DevicePrivateKeyFamily._()
    : super(
        retry: null,
        name: r'devicePrivateKeyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The private key for one device, or null if this phone does not hold it.
  ///
  /// A device issued on another phone, or one whose key was lost to a reinstall,
  /// still appears in `GET /devices` — the server has the public half. There is no
  /// way to recover the private key, so the UI has to say so rather than pretend.

  DevicePrivateKeyProvider call(String deviceId) =>
      DevicePrivateKeyProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'devicePrivateKeyProvider';
}

/// The platform value to send as `CreateDeviceDto.platform`.
///
/// Only the five values in `PLATFORMS` are accepted; anything else is a 400.

@ProviderFor(currentPlatform)
final currentPlatformProvider = CurrentPlatformProvider._();

/// The platform value to send as `CreateDeviceDto.platform`.
///
/// Only the five values in `PLATFORMS` are accepted; anything else is a 400.

final class CurrentPlatformProvider
    extends $FunctionalProvider<DevicePlatform, DevicePlatform, DevicePlatform>
    with $Provider<DevicePlatform> {
  /// The platform value to send as `CreateDeviceDto.platform`.
  ///
  /// Only the five values in `PLATFORMS` are accepted; anything else is a 400.
  CurrentPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPlatformProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPlatformHash();

  @$internal
  @override
  $ProviderElement<DevicePlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DevicePlatform create(Ref ref) {
    return currentPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevicePlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevicePlatform>(value),
    );
  }
}

String _$currentPlatformHash() => r'95986f7738f2cc7917433b5f1452af1dd32b87e0';
