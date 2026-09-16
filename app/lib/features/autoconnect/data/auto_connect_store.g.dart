// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_connect_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(autoConnectStore)
final autoConnectStoreProvider = AutoConnectStoreProvider._();

final class AutoConnectStoreProvider
    extends
        $FunctionalProvider<
          AutoConnectStore,
          AutoConnectStore,
          AutoConnectStore
        >
    with $Provider<AutoConnectStore> {
  AutoConnectStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoConnectStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoConnectStoreHash();

  @$internal
  @override
  $ProviderElement<AutoConnectStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutoConnectStore create(Ref ref) {
    return autoConnectStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoConnectStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoConnectStore>(value),
    );
  }
}

String _$autoConnectStoreHash() => r'ed0cfd3a973362c38e925ecbb39710413e73bacd';
