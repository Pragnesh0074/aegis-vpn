// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'excluded_apps_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(excludedAppsStore)
final excludedAppsStoreProvider = ExcludedAppsStoreProvider._();

final class ExcludedAppsStoreProvider
    extends
        $FunctionalProvider<
          ExcludedAppsStore,
          ExcludedAppsStore,
          ExcludedAppsStore
        >
    with $Provider<ExcludedAppsStore> {
  ExcludedAppsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'excludedAppsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$excludedAppsStoreHash();

  @$internal
  @override
  $ProviderElement<ExcludedAppsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExcludedAppsStore create(Ref ref) {
    return excludedAppsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExcludedAppsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExcludedAppsStore>(value),
    );
  }
}

String _$excludedAppsStoreHash() => r'66cf1c254261536d42d0335a4453351d46c2d0ad';
