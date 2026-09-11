// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nodes_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active node fleet.
///
/// `keepAlive` so the connect screen's location line does not re-fetch the list
/// the locations screen already has.

@ProviderFor(vpnNodes)
final vpnNodesProvider = VpnNodesProvider._();

/// The active node fleet.
///
/// `keepAlive` so the connect screen's location line does not re-fetch the list
/// the locations screen already has.

final class VpnNodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VpnNode>>,
          List<VpnNode>,
          FutureOr<List<VpnNode>>
        >
    with $FutureModifier<List<VpnNode>>, $FutureProvider<List<VpnNode>> {
  /// The active node fleet.
  ///
  /// `keepAlive` so the connect screen's location line does not re-fetch the list
  /// the locations screen already has.
  VpnNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vpnNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vpnNodesHash();

  @$internal
  @override
  $FutureProviderElement<List<VpnNode>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VpnNode>> create(Ref ref) {
    return vpnNodes(ref);
  }
}

String _$vpnNodesHash() => r'9d9f6e47d1b95bcdf90fdb43930fb2567feb85b6';

/// The fleet as countries, which is the only shape the locations screen shows.
///
/// The API returns nodes ordered by `(region, name)`; that ordering is not
/// useful once regions are read as countries, so [VpnLocation.group] re-sorts.

@ProviderFor(vpnLocations)
final vpnLocationsProvider = VpnLocationsProvider._();

/// The fleet as countries, which is the only shape the locations screen shows.
///
/// The API returns nodes ordered by `(region, name)`; that ordering is not
/// useful once regions are read as countries, so [VpnLocation.group] re-sorts.

final class VpnLocationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VpnLocation>>,
          List<VpnLocation>,
          FutureOr<List<VpnLocation>>
        >
    with
        $FutureModifier<List<VpnLocation>>,
        $FutureProvider<List<VpnLocation>> {
  /// The fleet as countries, which is the only shape the locations screen shows.
  ///
  /// The API returns nodes ordered by `(region, name)`; that ordering is not
  /// useful once regions are read as countries, so [VpnLocation.group] re-sorts.
  VpnLocationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vpnLocationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vpnLocationsHash();

  @$internal
  @override
  $FutureProviderElement<List<VpnLocation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VpnLocation>> create(Ref ref) {
    return vpnLocations(ref);
  }
}

String _$vpnLocationsHash() => r'fc07127d2c891f9c1d04bf075bc72835f6fd9b17';
