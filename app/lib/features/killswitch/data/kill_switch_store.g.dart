// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kill_switch_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(killSwitchStore)
final killSwitchStoreProvider = KillSwitchStoreProvider._();

final class KillSwitchStoreProvider
    extends
        $FunctionalProvider<KillSwitchStore, KillSwitchStore, KillSwitchStore>
    with $Provider<KillSwitchStore> {
  KillSwitchStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'killSwitchStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$killSwitchStoreHash();

  @$internal
  @override
  $ProviderElement<KillSwitchStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KillSwitchStore create(Ref ref) {
    return killSwitchStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KillSwitchStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KillSwitchStore>(value),
    );
  }
}

String _$killSwitchStoreHash() => r'8ce745b6b7fa372c29900e655cf613c0a20bf319';
