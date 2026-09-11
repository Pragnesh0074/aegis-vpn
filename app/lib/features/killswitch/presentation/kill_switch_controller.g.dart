// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kill_switch_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The kill switch setting, and the job of keeping the platform in step with it.
///
/// Two sources of truth have to be reconciled. The stored preference survives
/// restarts; the platform flag is what actually rebuilds a dropped tunnel and is
/// lost when the process dies. So the stored value is pushed down to the platform
/// on first read, and every change is written to both.
///
/// The platform is told first. If that fails there is nothing to persist — a
/// stored `true` whose platform never heard about it is exactly the silent
/// no-protection case this feature exists to avoid.

@ProviderFor(KillSwitchController)
final killSwitchControllerProvider = KillSwitchControllerProvider._();

/// The kill switch setting, and the job of keeping the platform in step with it.
///
/// Two sources of truth have to be reconciled. The stored preference survives
/// restarts; the platform flag is what actually rebuilds a dropped tunnel and is
/// lost when the process dies. So the stored value is pushed down to the platform
/// on first read, and every change is written to both.
///
/// The platform is told first. If that fails there is nothing to persist — a
/// stored `true` whose platform never heard about it is exactly the silent
/// no-protection case this feature exists to avoid.
final class KillSwitchControllerProvider
    extends $AsyncNotifierProvider<KillSwitchController, bool> {
  /// The kill switch setting, and the job of keeping the platform in step with it.
  ///
  /// Two sources of truth have to be reconciled. The stored preference survives
  /// restarts; the platform flag is what actually rebuilds a dropped tunnel and is
  /// lost when the process dies. So the stored value is pushed down to the platform
  /// on first read, and every change is written to both.
  ///
  /// The platform is told first. If that fails there is nothing to persist — a
  /// stored `true` whose platform never heard about it is exactly the silent
  /// no-protection case this feature exists to avoid.
  KillSwitchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'killSwitchControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$killSwitchControllerHash();

  @$internal
  @override
  KillSwitchController create() => KillSwitchController();
}

String _$killSwitchControllerHash() =>
    r'7736886c54542451983056f928dfe1c22192515b';

/// The kill switch setting, and the job of keeping the platform in step with it.
///
/// Two sources of truth have to be reconciled. The stored preference survives
/// restarts; the platform flag is what actually rebuilds a dropped tunnel and is
/// lost when the process dies. So the stored value is pushed down to the platform
/// on first read, and every change is written to both.
///
/// The platform is told first. If that fails there is nothing to persist — a
/// stored `true` whose platform never heard about it is exactly the silent
/// no-protection case this feature exists to avoid.

abstract class _$KillSwitchController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
