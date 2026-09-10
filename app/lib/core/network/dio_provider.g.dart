// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appConfig)
final appConfigProvider = AppConfigProvider._();

final class AppConfigProvider
    extends $FunctionalProvider<AppConfig, AppConfig, AppConfig>
    with $Provider<AppConfig> {
  AppConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appConfigHash();

  @$internal
  @override
  $ProviderElement<AppConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppConfig create(Ref ref) {
    return appConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppConfig>(value),
    );
  }
}

String _$appConfigHash() => r'87f9d20a2d92252672162b2ce97547b7b2479239';

/// A Dio with no auth interceptor.
///
/// Used for `/auth/*` and `/health`, and — importantly — as the client the
/// interceptor itself uses to refresh and to replay a retried request. Sharing the
/// authenticated client for that would recurse.

@ProviderFor(rawDio)
final rawDioProvider = RawDioProvider._();

/// A Dio with no auth interceptor.
///
/// Used for `/auth/*` and `/health`, and — importantly — as the client the
/// interceptor itself uses to refresh and to replay a retried request. Sharing the
/// authenticated client for that would recurse.

final class RawDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// A Dio with no auth interceptor.
  ///
  /// Used for `/auth/*` and `/health`, and — importantly — as the client the
  /// interceptor itself uses to refresh and to replay a retried request. Sharing the
  /// authenticated client for that would recurse.
  RawDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rawDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rawDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return rawDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$rawDioHash() => r'22f53846bbd489c2ac3a3396ec23f0ae2c184f34';

/// The client every authenticated repository uses.

@ProviderFor(authedDio)
final authedDioProvider = AuthedDioProvider._();

/// The client every authenticated repository uses.

final class AuthedDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// The client every authenticated repository uses.
  AuthedDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authedDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authedDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return authedDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$authedDioHash() => r'5a86671de8ea42f25f7e3e45ce72b5312b397180';
