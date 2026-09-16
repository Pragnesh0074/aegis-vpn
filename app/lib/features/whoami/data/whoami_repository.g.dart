// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whoami_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Built on the **unauthenticated** client on purpose.
///
/// The check has to work at the two moments an access token is least reliable:
/// right after the interface comes up, and while a refresh is in flight over a
/// route that has just changed underneath it. Turning "am I protected?" into a
/// 401 would be the least useful possible answer, and the endpoint reveals
/// nothing a caller does not already know — its own address.

@ProviderFor(whoamiRepository)
final whoamiRepositoryProvider = WhoamiRepositoryProvider._();

/// Built on the **unauthenticated** client on purpose.
///
/// The check has to work at the two moments an access token is least reliable:
/// right after the interface comes up, and while a refresh is in flight over a
/// route that has just changed underneath it. Turning "am I protected?" into a
/// 401 would be the least useful possible answer, and the endpoint reveals
/// nothing a caller does not already know — its own address.

final class WhoamiRepositoryProvider
    extends
        $FunctionalProvider<
          WhoamiRepository,
          WhoamiRepository,
          WhoamiRepository
        >
    with $Provider<WhoamiRepository> {
  /// Built on the **unauthenticated** client on purpose.
  ///
  /// The check has to work at the two moments an access token is least reliable:
  /// right after the interface comes up, and while a refresh is in flight over a
  /// route that has just changed underneath it. Turning "am I protected?" into a
  /// 401 would be the least useful possible answer, and the endpoint reveals
  /// nothing a caller does not already know — its own address.
  WhoamiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whoamiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whoamiRepositoryHash();

  @$internal
  @override
  $ProviderElement<WhoamiRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WhoamiRepository create(Ref ref) {
    return whoamiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WhoamiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WhoamiRepository>(value),
    );
  }
}

String _$whoamiRepositoryHash() => r'f462d1022012c7a89098b0a135fea3ec9add1e6e';
