// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auto_connect_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auto-connect, and the job of keeping the platform in step with it.
///
/// Same two-sources-of-truth shape as the kill switch, for the same reason: the
/// stored preference survives a restart, the platform flag is what actually
/// watches for networks and dies with the process. The platform is told first —
/// a stored `true` the platform never heard about is a feature that silently
/// does nothing.

@ProviderFor(AutoConnect)
final autoConnectProvider = AutoConnectProvider._();

/// Auto-connect, and the job of keeping the platform in step with it.
///
/// Same two-sources-of-truth shape as the kill switch, for the same reason: the
/// stored preference survives a restart, the platform flag is what actually
/// watches for networks and dies with the process. The platform is told first —
/// a stored `true` the platform never heard about is a feature that silently
/// does nothing.
final class AutoConnectProvider
    extends $AsyncNotifierProvider<AutoConnect, AutoConnectSettings> {
  /// Auto-connect, and the job of keeping the platform in step with it.
  ///
  /// Same two-sources-of-truth shape as the kill switch, for the same reason: the
  /// stored preference survives a restart, the platform flag is what actually
  /// watches for networks and dies with the process. The platform is told first —
  /// a stored `true` the platform never heard about is a feature that silently
  /// does nothing.
  AutoConnectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoConnectProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoConnectHash();

  @$internal
  @override
  AutoConnect create() => AutoConnect();
}

String _$autoConnectHash() => r'661ef23260bdc717d3d836248637facff0dec8d2';

/// Auto-connect, and the job of keeping the platform in step with it.
///
/// Same two-sources-of-truth shape as the kill switch, for the same reason: the
/// stored preference survives a restart, the platform flag is what actually
/// watches for networks and dies with the process. The platform is told first —
/// a stored `true` the platform never heard about is a feature that silently
/// does nothing.

abstract class _$AutoConnect extends $AsyncNotifier<AutoConnectSettings> {
  FutureOr<AutoConnectSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AutoConnectSettings>, AutoConnectSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AutoConnectSettings>, AutoConnectSettings>,
              AsyncValue<AutoConnectSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The network this device is on right now, for the "trust this network" row.
///
/// Auto-disposing and re-read each time the screen is opened, because it is the
/// one value here that changes without the app doing anything.

@ProviderFor(currentWifi)
final currentWifiProvider = CurrentWifiProvider._();

/// The network this device is on right now, for the "trust this network" row.
///
/// Auto-disposing and re-read each time the screen is opened, because it is the
/// one value here that changes without the app doing anything.

final class CurrentWifiProvider
    extends
        $FunctionalProvider<
          AsyncValue<WifiNetwork>,
          WifiNetwork,
          FutureOr<WifiNetwork>
        >
    with $FutureModifier<WifiNetwork>, $FutureProvider<WifiNetwork> {
  /// The network this device is on right now, for the "trust this network" row.
  ///
  /// Auto-disposing and re-read each time the screen is opened, because it is the
  /// one value here that changes without the app doing anything.
  CurrentWifiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentWifiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentWifiHash();

  @$internal
  @override
  $FutureProviderElement<WifiNetwork> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WifiNetwork> create(Ref ref) {
    return currentWifi(ref);
  }
}

String _$currentWifiHash() => r'8ca55771d5c41842907c3038ae029716a6f1dee8';
