// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's router, with auth-gating in a single `redirect`.
///
/// Gating centrally — rather than each screen checking for a session — is what
/// makes the interceptor's "refresh token rejected" path work: it flips
/// [sessionProvider] to unauthenticated and every screen in the stack unwinds to
/// the login page, wherever the user happened to be.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The app's router, with auth-gating in a single `redirect`.
///
/// Gating centrally — rather than each screen checking for a session — is what
/// makes the interceptor's "refresh token rejected" path work: it flips
/// [sessionProvider] to unauthenticated and every screen in the stack unwinds to
/// the login page, wherever the user happened to be.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The app's router, with auth-gating in a single `redirect`.
  ///
  /// Gating centrally — rather than each screen checking for a session — is what
  /// makes the interceptor's "refresh token rejected" path work: it flips
  /// [sessionProvider] to unauthenticated and every screen in the stack unwinds to
  /// the login page, wherever the user happened to be.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'68be2f33b014a1c779de99e0f28b1ff588a8d1a6';
