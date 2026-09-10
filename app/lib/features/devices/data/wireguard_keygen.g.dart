// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wireguard_keygen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wireguardKeygen)
final wireguardKeygenProvider = WireguardKeygenProvider._();

final class WireguardKeygenProvider
    extends
        $FunctionalProvider<WireguardKeygen, WireguardKeygen, WireguardKeygen>
    with $Provider<WireguardKeygen> {
  WireguardKeygenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wireguardKeygenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wireguardKeygenHash();

  @$internal
  @override
  $ProviderElement<WireguardKeygen> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WireguardKeygen create(Ref ref) {
    return wireguardKeygen(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WireguardKeygen value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WireguardKeygen>(value),
    );
  }
}

String _$wireguardKeygenHash() => r'49d4fa99627356ba5d63c6458677e3c32bd31020';
