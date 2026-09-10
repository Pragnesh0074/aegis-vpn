// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Mutations on the device list: issuing a peer and revoking one.
///
/// Reads stay in [devicesProvider]. Keeping them apart means a failed mutation
/// shows an error without blanking the list the user is looking at.

@ProviderFor(DevicesController)
final devicesControllerProvider = DevicesControllerProvider._();

/// Mutations on the device list: issuing a peer and revoking one.
///
/// Reads stay in [devicesProvider]. Keeping them apart means a failed mutation
/// shows an error without blanking the list the user is looking at.
final class DevicesControllerProvider
    extends $AsyncNotifierProvider<DevicesController, void> {
  /// Mutations on the device list: issuing a peer and revoking one.
  ///
  /// Reads stay in [devicesProvider]. Keeping them apart means a failed mutation
  /// shows an error without blanking the list the user is looking at.
  DevicesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicesControllerHash();

  @$internal
  @override
  DevicesController create() => DevicesController();
}

String _$devicesControllerHash() => r'6976265424ad1e3755b3c4813b12be7aeeddfacf';

/// Mutations on the device list: issuing a peer and revoking one.
///
/// Reads stay in [devicesProvider]. Keeping them apart means a failed mutation
/// shows an error without blanking the list the user is looking at.

abstract class _$DevicesController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
