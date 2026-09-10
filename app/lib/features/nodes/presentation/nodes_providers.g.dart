// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nodes_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active node fleet.
///
/// `keepAlive` so the picker on the add-device sheet does not re-fetch the list
/// the servers tab already has.

@ProviderFor(vpnNodes)
final vpnNodesProvider = VpnNodesProvider._();

/// The active node fleet.
///
/// `keepAlive` so the picker on the add-device sheet does not re-fetch the list
/// the servers tab already has.

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
  /// `keepAlive` so the picker on the add-device sheet does not re-fetch the list
  /// the servers tab already has.
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

/// Nodes grouped by region, for a sectioned list. The API already returns them
/// ordered by `(region, name)`, so a single pass preserves that order.

@ProviderFor(vpnNodesByRegion)
final vpnNodesByRegionProvider = VpnNodesByRegionProvider._();

/// Nodes grouped by region, for a sectioned list. The API already returns them
/// ordered by `(region, name)`, so a single pass preserves that order.

final class VpnNodesByRegionProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<VpnNode>>>,
          Map<String, List<VpnNode>>,
          FutureOr<Map<String, List<VpnNode>>>
        >
    with
        $FutureModifier<Map<String, List<VpnNode>>>,
        $FutureProvider<Map<String, List<VpnNode>>> {
  /// Nodes grouped by region, for a sectioned list. The API already returns them
  /// ordered by `(region, name)`, so a single pass preserves that order.
  VpnNodesByRegionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vpnNodesByRegionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vpnNodesByRegionHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<VpnNode>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<VpnNode>>> create(Ref ref) {
    return vpnNodesByRegion(ref);
  }
}

String _$vpnNodesByRegionHash() => r'1c054efeceab05d92201c0b81a5ccf49c66dd783';
