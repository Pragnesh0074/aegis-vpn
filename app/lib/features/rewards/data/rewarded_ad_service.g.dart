// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rewarded_ad_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rewardedAdService)
final rewardedAdServiceProvider = RewardedAdServiceProvider._();

final class RewardedAdServiceProvider
    extends
        $FunctionalProvider<
          RewardedAdService,
          RewardedAdService,
          RewardedAdService
        >
    with $Provider<RewardedAdService> {
  RewardedAdServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rewardedAdServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rewardedAdServiceHash();

  @$internal
  @override
  $ProviderElement<RewardedAdService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RewardedAdService create(Ref ref) {
    return rewardedAdService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RewardedAdService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RewardedAdService>(value),
    );
  }
}

String _$rewardedAdServiceHash() => r'14f6eb319cd06b137fb3f744780a95c3d3c93208';
