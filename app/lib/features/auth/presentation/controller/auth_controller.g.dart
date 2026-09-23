// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the sign-in and sign-up forms.
///
/// Holds only submission state — whether a request is in flight and whether it
/// failed. Who is signed in lives in [sessionProvider]; duplicating it here would
/// give the app two answers to the same question.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Drives the sign-in and sign-up forms.
///
/// Holds only submission state — whether a request is in flight and whether it
/// failed. Who is signed in lives in [sessionProvider]; duplicating it here would
/// give the app two answers to the same question.
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, void> {
  /// Drives the sign-in and sign-up forms.
  ///
  /// Holds only submission state — whether a request is in flight and whether it
  /// failed. Who is signed in lives in [sessionProvider]; duplicating it here would
  /// give the app two answers to the same question.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'7337d8206aac9e3b427396d802f169d32eef3eef';

/// Drives the sign-in and sign-up forms.
///
/// Holds only submission state — whether a request is in flight and whether it
/// failed. Who is signed in lives in [sessionProvider]; duplicating it here would
/// give the app two answers to the same question.

abstract class _$AuthController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
