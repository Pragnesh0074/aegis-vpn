// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_block_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The ad-blocking setting.
///
/// Unlike the kill switch, nothing about this lives on the phone. The filtering
/// happens on the node, and which of its two resolvers a device is handed is
/// decided server-side from the account's preference. So the source of truth is
/// `/users/me`, not a local store.
///
/// That makes the write a three-step job, and all three have to happen or the
/// switch lies: save the preference, re-read the device config so the phone has
/// the new resolver, and rebuild the tunnel — the resolver is part of the
/// WireGuard `[Interface]` and a live interface will keep using the old one
/// until it is torn down.

@ProviderFor(AdBlockController)
final adBlockControllerProvider = AdBlockControllerProvider._();

/// The ad-blocking setting.
///
/// Unlike the kill switch, nothing about this lives on the phone. The filtering
/// happens on the node, and which of its two resolvers a device is handed is
/// decided server-side from the account's preference. So the source of truth is
/// `/users/me`, not a local store.
///
/// That makes the write a three-step job, and all three have to happen or the
/// switch lies: save the preference, re-read the device config so the phone has
/// the new resolver, and rebuild the tunnel — the resolver is part of the
/// WireGuard `[Interface]` and a live interface will keep using the old one
/// until it is torn down.
final class AdBlockControllerProvider
    extends $AsyncNotifierProvider<AdBlockController, bool> {
  /// The ad-blocking setting.
  ///
  /// Unlike the kill switch, nothing about this lives on the phone. The filtering
  /// happens on the node, and which of its two resolvers a device is handed is
  /// decided server-side from the account's preference. So the source of truth is
  /// `/users/me`, not a local store.
  ///
  /// That makes the write a three-step job, and all three have to happen or the
  /// switch lies: save the preference, re-read the device config so the phone has
  /// the new resolver, and rebuild the tunnel — the resolver is part of the
  /// WireGuard `[Interface]` and a live interface will keep using the old one
  /// until it is torn down.
  AdBlockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adBlockControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adBlockControllerHash();

  @$internal
  @override
  AdBlockController create() => AdBlockController();
}

String _$adBlockControllerHash() => r'7b8607914316a9984491466d8cc4afa7518c60e4';

/// The ad-blocking setting.
///
/// Unlike the kill switch, nothing about this lives on the phone. The filtering
/// happens on the node, and which of its two resolvers a device is handed is
/// decided server-side from the account's preference. So the source of truth is
/// `/users/me`, not a local store.
///
/// That makes the write a three-step job, and all three have to happen or the
/// switch lies: save the preference, re-read the device config so the phone has
/// the new resolver, and rebuild the tunnel — the resolver is part of the
/// WireGuard `[Interface]` and a live interface will keep using the old one
/// until it is torn down.

abstract class _$AdBlockController extends $AsyncNotifier<bool> {
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
