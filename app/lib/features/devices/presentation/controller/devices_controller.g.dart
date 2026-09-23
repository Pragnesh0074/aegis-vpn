// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Revoking a peer from the device list.
///
/// Issuing one lives in `VpnSession` instead, because it now happens as part of
/// connecting rather than as its own user-facing step. Reads stay in
/// [devicesProvider]: keeping them apart means a failed revoke shows an error
/// without blanking the list the user is looking at.

@ProviderFor(DevicesController)
final devicesControllerProvider = DevicesControllerProvider._();

/// Revoking a peer from the device list.
///
/// Issuing one lives in `VpnSession` instead, because it now happens as part of
/// connecting rather than as its own user-facing step. Reads stay in
/// [devicesProvider]: keeping them apart means a failed revoke shows an error
/// without blanking the list the user is looking at.
final class DevicesControllerProvider
    extends $AsyncNotifierProvider<DevicesController, void> {
  /// Revoking a peer from the device list.
  ///
  /// Issuing one lives in `VpnSession` instead, because it now happens as part of
  /// connecting rather than as its own user-facing step. Reads stay in
  /// [devicesProvider]: keeping them apart means a failed revoke shows an error
  /// without blanking the list the user is looking at.
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

String _$devicesControllerHash() => r'e66407b917f709289c19834d5978e164ab443b22';

/// Revoking a peer from the device list.
///
/// Issuing one lives in `VpnSession` instead, because it now happens as part of
/// connecting rather than as its own user-facing step. Reads stay in
/// [devicesProvider]: keeping them apart means a failed revoke shows an error
/// without blanking the list the user is looking at.

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
