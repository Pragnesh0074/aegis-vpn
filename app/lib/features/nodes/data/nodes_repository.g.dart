// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nodes_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nodesRepository)
final nodesRepositoryProvider = NodesRepositoryProvider._();

final class NodesRepositoryProvider
    extends
        $FunctionalProvider<NodesRepository, NodesRepository, NodesRepository>
    with $Provider<NodesRepository> {
  NodesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodesRepositoryHash();

  @$internal
  @override
  $ProviderElement<NodesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NodesRepository create(Ref ref) {
    return nodesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodesRepository>(value),
    );
  }
}

String _$nodesRepositoryHash() => r'6cbedd4b175c5005a37ef4989e066889d9ae6128';
