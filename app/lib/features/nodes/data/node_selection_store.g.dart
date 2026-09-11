// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'node_selection_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nodeSelectionStore)
final nodeSelectionStoreProvider = NodeSelectionStoreProvider._();

final class NodeSelectionStoreProvider
    extends
        $FunctionalProvider<
          NodeSelectionStore,
          NodeSelectionStore,
          NodeSelectionStore
        >
    with $Provider<NodeSelectionStore> {
  NodeSelectionStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeSelectionStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeSelectionStoreHash();

  @$internal
  @override
  $ProviderElement<NodeSelectionStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NodeSelectionStore create(Ref ref) {
    return nodeSelectionStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodeSelectionStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodeSelectionStore>(value),
    );
  }
}

String _$nodeSelectionStoreHash() =>
    r'dbfdf8213ca0160147dc2b2e23a774365fc2b99b';
