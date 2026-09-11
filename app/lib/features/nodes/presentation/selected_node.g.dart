// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_node.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The node the user chose, or null for automatic.
///
/// Hydrated from the keystore, so the choice survives a restart. Automatic is a
/// real state rather than a stand-in for "not loaded yet": it means the app
/// omits `nodeId` from `POST /devices` and lets the backend pick.

@ProviderFor(SelectedNodeId)
final selectedNodeIdProvider = SelectedNodeIdProvider._();

/// The node the user chose, or null for automatic.
///
/// Hydrated from the keystore, so the choice survives a restart. Automatic is a
/// real state rather than a stand-in for "not loaded yet": it means the app
/// omits `nodeId` from `POST /devices` and lets the backend pick.
final class SelectedNodeIdProvider
    extends $AsyncNotifierProvider<SelectedNodeId, String?> {
  /// The node the user chose, or null for automatic.
  ///
  /// Hydrated from the keystore, so the choice survives a restart. Automatic is a
  /// real state rather than a stand-in for "not loaded yet": it means the app
  /// omits `nodeId` from `POST /devices` and lets the backend pick.
  SelectedNodeIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedNodeIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedNodeIdHash();

  @$internal
  @override
  SelectedNodeId create() => SelectedNodeId();
}

String _$selectedNodeIdHash() => r'24d0eb0e5aacf92548d22ee361fb02d9f10572b5';

/// The node the user chose, or null for automatic.
///
/// Hydrated from the keystore, so the choice survives a restart. Automatic is a
/// real state rather than a stand-in for "not loaded yet": it means the app
/// omits `nodeId` from `POST /devices` and lets the backend pick.

abstract class _$SelectedNodeId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The chosen node resolved against the live fleet, or null on automatic.
///
/// Resolving rather than trusting the stored id matters: a node can be
/// deactivated or removed between runs, and a dangling id would otherwise show
/// as a location that no longer exists and fail at `POST /devices` with a 404.
/// An unresolvable id reads as automatic, which still connects.

@ProviderFor(selectedNode)
final selectedNodeProvider = SelectedNodeProvider._();

/// The chosen node resolved against the live fleet, or null on automatic.
///
/// Resolving rather than trusting the stored id matters: a node can be
/// deactivated or removed between runs, and a dangling id would otherwise show
/// as a location that no longer exists and fail at `POST /devices` with a 404.
/// An unresolvable id reads as automatic, which still connects.

final class SelectedNodeProvider
    extends
        $FunctionalProvider<AsyncValue<VpnNode?>, VpnNode?, FutureOr<VpnNode?>>
    with $FutureModifier<VpnNode?>, $FutureProvider<VpnNode?> {
  /// The chosen node resolved against the live fleet, or null on automatic.
  ///
  /// Resolving rather than trusting the stored id matters: a node can be
  /// deactivated or removed between runs, and a dangling id would otherwise show
  /// as a location that no longer exists and fail at `POST /devices` with a 404.
  /// An unresolvable id reads as automatic, which still connects.
  SelectedNodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedNodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedNodeHash();

  @$internal
  @override
  $FutureProviderElement<VpnNode?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<VpnNode?> create(Ref ref) {
    return selectedNode(ref);
  }
}

String _$selectedNodeHash() => r'2be4bf64d380a518efb4677a799bd94a4ca35854';

/// What automatic would most likely give you: the emptiest node with capacity.
///
/// Only a prediction — the backend runs the same rule at issue time and its
/// answer is the one that counts — but the locations screen has to label a row
/// "Fastest" and an empty node is the honest guess.

@ProviderFor(fastestNode)
final fastestNodeProvider = FastestNodeProvider._();

/// What automatic would most likely give you: the emptiest node with capacity.
///
/// Only a prediction — the backend runs the same rule at issue time and its
/// answer is the one that counts — but the locations screen has to label a row
/// "Fastest" and an empty node is the honest guess.

final class FastestNodeProvider
    extends
        $FunctionalProvider<AsyncValue<VpnNode?>, VpnNode?, FutureOr<VpnNode?>>
    with $FutureModifier<VpnNode?>, $FutureProvider<VpnNode?> {
  /// What automatic would most likely give you: the emptiest node with capacity.
  ///
  /// Only a prediction — the backend runs the same rule at issue time and its
  /// answer is the one that counts — but the locations screen has to label a row
  /// "Fastest" and an empty node is the honest guess.
  FastestNodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fastestNodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fastestNodeHash();

  @$internal
  @override
  $FutureProviderElement<VpnNode?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<VpnNode?> create(Ref ref) {
    return fastestNode(ref);
  }
}

String _$fastestNodeHash() => r'198d5dacd68c84ccb16f2d5a166b4a889907d727';

/// The location line the connect screen headlines, resolved for either mode.
///
/// On automatic this reports the node automatic would pick, flagged as such, so
/// the screen never has to show a bare "Automatic" with no country attached.

@ProviderFor(locationChoice)
final locationChoiceProvider = LocationChoiceProvider._();

/// The location line the connect screen headlines, resolved for either mode.
///
/// On automatic this reports the node automatic would pick, flagged as such, so
/// the screen never has to show a bare "Automatic" with no country attached.

final class LocationChoiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<LocationChoice>,
          LocationChoice,
          FutureOr<LocationChoice>
        >
    with $FutureModifier<LocationChoice>, $FutureProvider<LocationChoice> {
  /// The location line the connect screen headlines, resolved for either mode.
  ///
  /// On automatic this reports the node automatic would pick, flagged as such, so
  /// the screen never has to show a bare "Automatic" with no country attached.
  LocationChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationChoiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationChoiceHash();

  @$internal
  @override
  $FutureProviderElement<LocationChoice> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LocationChoice> create(Ref ref) {
    return locationChoice(ref);
  }
}

String _$locationChoiceHash() => r'646dfaf7421604062f78ca76bd0e23630275a5b6';
