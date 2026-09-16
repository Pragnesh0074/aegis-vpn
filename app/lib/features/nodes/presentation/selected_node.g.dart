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

/// The device's offset from UTC, which is all the location this app asks for.
///
/// A provider rather than a direct `DateTime.now()` call so a test can place the
/// device somewhere without moving the machine's clock. See [NodeRanking] for
/// why a time zone is the signal being used.

@ProviderFor(deviceUtcOffset)
final deviceUtcOffsetProvider = DeviceUtcOffsetProvider._();

/// The device's offset from UTC, which is all the location this app asks for.
///
/// A provider rather than a direct `DateTime.now()` call so a test can place the
/// device somewhere without moving the machine's clock. See [NodeRanking] for
/// why a time zone is the signal being used.

final class DeviceUtcOffsetProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// The device's offset from UTC, which is all the location this app asks for.
  ///
  /// A provider rather than a direct `DateTime.now()` call so a test can place the
  /// device somewhere without moving the machine's clock. See [NodeRanking] for
  /// why a time zone is the signal being used.
  DeviceUtcOffsetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceUtcOffsetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceUtcOffsetHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return deviceUtcOffset(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$deviceUtcOffsetHash() => r'5c38aecaa8d81dc45615c2ab934120c654f45e5a';

/// What automatic resolves to: the nearest node with capacity.
///
/// No longer a prediction of what the backend would do. The client picks, and
/// sends that node id on `POST /devices` — see `VpnSession._ensureDevice`. The
/// backend's `selectLeastLoaded()` remains the fallback for a request that names
/// no node, which now happens only when there is nothing to rank by.
///
/// The client is the right place for this: it is the only party that knows where
/// the device is, and it already had to compute this answer to put a country on
/// the connect screen. Leaving the decision on the server meant the screen
/// predicted one node while the server chose another, and the two disagreed
/// exactly when the fleet was busy.

@ProviderFor(nearestNode)
final nearestNodeProvider = NearestNodeProvider._();

/// What automatic resolves to: the nearest node with capacity.
///
/// No longer a prediction of what the backend would do. The client picks, and
/// sends that node id on `POST /devices` — see `VpnSession._ensureDevice`. The
/// backend's `selectLeastLoaded()` remains the fallback for a request that names
/// no node, which now happens only when there is nothing to rank by.
///
/// The client is the right place for this: it is the only party that knows where
/// the device is, and it already had to compute this answer to put a country on
/// the connect screen. Leaving the decision on the server meant the screen
/// predicted one node while the server chose another, and the two disagreed
/// exactly when the fleet was busy.

final class NearestNodeProvider
    extends
        $FunctionalProvider<AsyncValue<VpnNode?>, VpnNode?, FutureOr<VpnNode?>>
    with $FutureModifier<VpnNode?>, $FutureProvider<VpnNode?> {
  /// What automatic resolves to: the nearest node with capacity.
  ///
  /// No longer a prediction of what the backend would do. The client picks, and
  /// sends that node id on `POST /devices` — see `VpnSession._ensureDevice`. The
  /// backend's `selectLeastLoaded()` remains the fallback for a request that names
  /// no node, which now happens only when there is nothing to rank by.
  ///
  /// The client is the right place for this: it is the only party that knows where
  /// the device is, and it already had to compute this answer to put a country on
  /// the connect screen. Leaving the decision on the server meant the screen
  /// predicted one node while the server chose another, and the two disagreed
  /// exactly when the fleet was busy.
  NearestNodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nearestNodeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearestNodeHash();

  @$internal
  @override
  $FutureProviderElement<VpnNode?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<VpnNode?> create(Ref ref) {
    return nearestNode(ref);
  }
}

String _$nearestNodeHash() => r'3bd930d3a6ead7bac89f958926da62f0d41e4aba';

/// The location line the connect screen headlines, resolved for either mode.
///
/// On automatic this reports the node automatic will pick, flagged as such, so
/// the screen never has to show a bare "Automatic" with no country attached.

@ProviderFor(locationChoice)
final locationChoiceProvider = LocationChoiceProvider._();

/// The location line the connect screen headlines, resolved for either mode.
///
/// On automatic this reports the node automatic will pick, flagged as such, so
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
  /// On automatic this reports the node automatic will pick, flagged as such, so
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

String _$locationChoiceHash() => r'82c030e3ee554c3f5b4ca1fadce47fe493345bdb';
