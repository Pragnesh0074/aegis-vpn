// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_block_grant_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the countdown and the watch-an-ad flow.
///
/// The countdown is driven locally from a single server-supplied duration rather
/// than by polling: the server is the authority on when a grant ends, but asking
/// it every second to render a clock would be absurd. Local drift does not
/// matter, because the client cannot grant itself anything — when the timer hits
/// zero the client re-reads its config and the server hands back the unfiltered
/// resolver, or does not, entirely on its own reckoning.

@ProviderFor(AdBlockGrantController)
final adBlockGrantControllerProvider = AdBlockGrantControllerProvider._();

/// Owns the countdown and the watch-an-ad flow.
///
/// The countdown is driven locally from a single server-supplied duration rather
/// than by polling: the server is the authority on when a grant ends, but asking
/// it every second to render a clock would be absurd. Local drift does not
/// matter, because the client cannot grant itself anything — when the timer hits
/// zero the client re-reads its config and the server hands back the unfiltered
/// resolver, or does not, entirely on its own reckoning.
final class AdBlockGrantControllerProvider
    extends $AsyncNotifierProvider<AdBlockGrantController, AdBlockGrant> {
  /// Owns the countdown and the watch-an-ad flow.
  ///
  /// The countdown is driven locally from a single server-supplied duration rather
  /// than by polling: the server is the authority on when a grant ends, but asking
  /// it every second to render a clock would be absurd. Local drift does not
  /// matter, because the client cannot grant itself anything — when the timer hits
  /// zero the client re-reads its config and the server hands back the unfiltered
  /// resolver, or does not, entirely on its own reckoning.
  AdBlockGrantControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adBlockGrantControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adBlockGrantControllerHash();

  @$internal
  @override
  AdBlockGrantController create() => AdBlockGrantController();
}

String _$adBlockGrantControllerHash() =>
    r'd0d00eca1fb8f40f236628ac1bd4c93aada44e04';

/// Owns the countdown and the watch-an-ad flow.
///
/// The countdown is driven locally from a single server-supplied duration rather
/// than by polling: the server is the authority on when a grant ends, but asking
/// it every second to render a clock would be absurd. Local drift does not
/// matter, because the client cannot grant itself anything — when the timer hits
/// zero the client re-reads its config and the server hands back the unfiltered
/// resolver, or does not, entirely on its own reckoning.

abstract class _$AdBlockGrantController extends $AsyncNotifier<AdBlockGrant> {
  FutureOr<AdBlockGrant> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AdBlockGrant>, AdBlockGrant>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AdBlockGrant>, AdBlockGrant>,
              AsyncValue<AdBlockGrant>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
