// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single source of truth for "is someone signed in".
///
/// The router watches this, the auth screens write to it, and the Dio interceptor
/// flips it to `unauthenticated` when a refresh token is rejected. Keeping it in
/// core is what lets all three agree without a cycle.

@ProviderFor(SessionNotifier)
final sessionProvider = SessionNotifierProvider._();

/// The single source of truth for "is someone signed in".
///
/// The router watches this, the auth screens write to it, and the Dio interceptor
/// flips it to `unauthenticated` when a refresh token is rejected. Keeping it in
/// core is what lets all three agree without a cycle.
final class SessionNotifierProvider
    extends $AsyncNotifierProvider<SessionNotifier, SessionStatus> {
  /// The single source of truth for "is someone signed in".
  ///
  /// The router watches this, the auth screens write to it, and the Dio interceptor
  /// flips it to `unauthenticated` when a refresh token is rejected. Keeping it in
  /// core is what lets all three agree without a cycle.
  SessionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionNotifierHash();

  @$internal
  @override
  SessionNotifier create() => SessionNotifier();
}

String _$sessionNotifierHash() => r'e3b5b090d03f294c299f7df0e3fc8615897c164c';

/// The single source of truth for "is someone signed in".
///
/// The router watches this, the auth screens write to it, and the Dio interceptor
/// flips it to `unauthenticated` when a refresh token is rejected. Keeping it in
/// core is what lets all three agree without a cycle.

abstract class _$SessionNotifier extends $AsyncNotifier<SessionStatus> {
  FutureOr<SessionStatus> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SessionStatus>, SessionStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SessionStatus>, SessionStatus>,
              AsyncValue<SessionStatus>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
