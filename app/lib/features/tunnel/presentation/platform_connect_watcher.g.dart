// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_connect_watcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Serves the platform's requests for a tunnel it cannot build itself.
///
/// Two things make such a request: auto-connect arriving at an untrusted network
/// with no config held, and the Quick Settings tile tapped on a cold start.
/// Neither can do the work — building a tunnel from nothing means reading a
/// private key out of the keystore and, on a fresh install, registering a peer
/// with the API. Both are Dart's.
///
/// The request is a standing flag rather than an event, and acknowledging it is
/// this notifier's other half. That is what makes a tile tap work: the tap
/// happens seconds before a Flutter engine exists, so anything the app had to
/// hear at that moment would be missed. Instead the request waits, and the first
/// thing to look serves it.
///
/// Watched by the signed-in shell, so it is alive exactly when there is an
/// account to provision against and never when there is not.

@ProviderFor(PlatformConnectWatcher)
final platformConnectWatcherProvider = PlatformConnectWatcherProvider._();

/// Serves the platform's requests for a tunnel it cannot build itself.
///
/// Two things make such a request: auto-connect arriving at an untrusted network
/// with no config held, and the Quick Settings tile tapped on a cold start.
/// Neither can do the work — building a tunnel from nothing means reading a
/// private key out of the keystore and, on a fresh install, registering a peer
/// with the API. Both are Dart's.
///
/// The request is a standing flag rather than an event, and acknowledging it is
/// this notifier's other half. That is what makes a tile tap work: the tap
/// happens seconds before a Flutter engine exists, so anything the app had to
/// hear at that moment would be missed. Instead the request waits, and the first
/// thing to look serves it.
///
/// Watched by the signed-in shell, so it is alive exactly when there is an
/// account to provision against and never when there is not.
final class PlatformConnectWatcherProvider
    extends $NotifierProvider<PlatformConnectWatcher, void> {
  /// Serves the platform's requests for a tunnel it cannot build itself.
  ///
  /// Two things make such a request: auto-connect arriving at an untrusted network
  /// with no config held, and the Quick Settings tile tapped on a cold start.
  /// Neither can do the work — building a tunnel from nothing means reading a
  /// private key out of the keystore and, on a fresh install, registering a peer
  /// with the API. Both are Dart's.
  ///
  /// The request is a standing flag rather than an event, and acknowledging it is
  /// this notifier's other half. That is what makes a tile tap work: the tap
  /// happens seconds before a Flutter engine exists, so anything the app had to
  /// hear at that moment would be missed. Instead the request waits, and the first
  /// thing to look serves it.
  ///
  /// Watched by the signed-in shell, so it is alive exactly when there is an
  /// account to provision against and never when there is not.
  PlatformConnectWatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformConnectWatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformConnectWatcherHash();

  @$internal
  @override
  PlatformConnectWatcher create() => PlatformConnectWatcher();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$platformConnectWatcherHash() =>
    r'84036d456ef4d15fea7399c76505694db8c80545';

/// Serves the platform's requests for a tunnel it cannot build itself.
///
/// Two things make such a request: auto-connect arriving at an untrusted network
/// with no config held, and the Quick Settings tile tapped on a cold start.
/// Neither can do the work — building a tunnel from nothing means reading a
/// private key out of the keystore and, on a fresh install, registering a peer
/// with the API. Both are Dart's.
///
/// The request is a standing flag rather than an event, and acknowledging it is
/// this notifier's other half. That is what makes a tile tap work: the tap
/// happens seconds before a Flutter engine exists, so anything the app had to
/// hear at that moment would be missed. Instead the request waits, and the first
/// thing to look serves it.
///
/// Watched by the signed-in shell, so it is alive exactly when there is an
/// account to provision against and never when there is not.

abstract class _$PlatformConnectWatcher extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
