// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_notice_watcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Turns the platform's Wi-Fi signals into stored state.
///
/// Three things arrive on the status stream and none of them can be handled by
/// the platform itself, because all three end in the trusted list — which lives
/// in Flutter's secure storage:
///
///  * a network was joined, so remember it for the "recently joined" list;
///  * a network was joined that is NOT trusted, so the UI should offer to trust
///    it — acknowledged here so the platform stops repeating it;
///  * the notification's "Trust this network" was tapped, possibly before the
///    app existed, so write it now and tell the platform it landed.
///
/// Watched from the shell for as long as there is a session, like the other
/// always-on listeners: the join this exists to catch happens with no screen
/// open, so anything mounted on a page would miss it.

@ProviderFor(WifiNoticeWatcher)
final wifiNoticeWatcherProvider = WifiNoticeWatcherProvider._();

/// Turns the platform's Wi-Fi signals into stored state.
///
/// Three things arrive on the status stream and none of them can be handled by
/// the platform itself, because all three end in the trusted list — which lives
/// in Flutter's secure storage:
///
///  * a network was joined, so remember it for the "recently joined" list;
///  * a network was joined that is NOT trusted, so the UI should offer to trust
///    it — acknowledged here so the platform stops repeating it;
///  * the notification's "Trust this network" was tapped, possibly before the
///    app existed, so write it now and tell the platform it landed.
///
/// Watched from the shell for as long as there is a session, like the other
/// always-on listeners: the join this exists to catch happens with no screen
/// open, so anything mounted on a page would miss it.
final class WifiNoticeWatcherProvider
    extends $NotifierProvider<WifiNoticeWatcher, String?> {
  /// Turns the platform's Wi-Fi signals into stored state.
  ///
  /// Three things arrive on the status stream and none of them can be handled by
  /// the platform itself, because all three end in the trusted list — which lives
  /// in Flutter's secure storage:
  ///
  ///  * a network was joined, so remember it for the "recently joined" list;
  ///  * a network was joined that is NOT trusted, so the UI should offer to trust
  ///    it — acknowledged here so the platform stops repeating it;
  ///  * the notification's "Trust this network" was tapped, possibly before the
  ///    app existed, so write it now and tell the platform it landed.
  ///
  /// Watched from the shell for as long as there is a session, like the other
  /// always-on listeners: the join this exists to catch happens with no screen
  /// open, so anything mounted on a page would miss it.
  WifiNoticeWatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wifiNoticeWatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wifiNoticeWatcherHash();

  @$internal
  @override
  WifiNoticeWatcher create() => WifiNoticeWatcher();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$wifiNoticeWatcherHash() => r'5b215ae618460264f2170a9bb2e755eddfe6a1bc';

/// Turns the platform's Wi-Fi signals into stored state.
///
/// Three things arrive on the status stream and none of them can be handled by
/// the platform itself, because all three end in the trusted list — which lives
/// in Flutter's secure storage:
///
///  * a network was joined, so remember it for the "recently joined" list;
///  * a network was joined that is NOT trusted, so the UI should offer to trust
///    it — acknowledged here so the platform stops repeating it;
///  * the notification's "Trust this network" was tapped, possibly before the
///    app existed, so write it now and tell the platform it landed.
///
/// Watched from the shell for as long as there is a session, like the other
/// always-on listeners: the join this exists to catch happens with no screen
/// open, so anything mounted on a page would miss it.

abstract class _$WifiNoticeWatcher extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
