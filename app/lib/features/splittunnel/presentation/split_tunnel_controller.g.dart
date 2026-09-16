// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_tunnel_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every app the picker can offer, straight from the platform.
///
/// `keepAlive` because the list costs a `PackageManager` query per call and does
/// not change while the user is looking at it.

@ProviderFor(installedApps)
final installedAppsProvider = InstalledAppsProvider._();

/// Every app the picker can offer, straight from the platform.
///
/// `keepAlive` because the list costs a `PackageManager` query per call and does
/// not change while the user is looking at it.

final class InstalledAppsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstalledApp>>,
          List<InstalledApp>,
          FutureOr<List<InstalledApp>>
        >
    with
        $FutureModifier<List<InstalledApp>>,
        $FutureProvider<List<InstalledApp>> {
  /// Every app the picker can offer, straight from the platform.
  ///
  /// `keepAlive` because the list costs a `PackageManager` query per call and does
  /// not change while the user is looking at it.
  InstalledAppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedAppsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedAppsHash();

  @$internal
  @override
  $FutureProviderElement<List<InstalledApp>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstalledApp>> create(Ref ref) {
    return installedApps(ref);
  }
}

String _$installedAppsHash() => r'd4dde20cc2b905ea6fed2fdcb2132a40de5d6160';

/// The packages kept off the tunnel.
///
/// Nothing is pushed to the platform here, and that is deliberate. An excluded
/// set only takes effect when an interface is built, so this writes the
/// preference and the next `connect` carries it — which also means a change made
/// while the tunnel is up does nothing until it is rebuilt. The screen says so
/// rather than silently reconnecting: dropping someone's tunnel because they
/// ticked a checkbox is a worse surprise than a banner asking them to.

@ProviderFor(ExcludedApps)
final excludedAppsProvider = ExcludedAppsProvider._();

/// The packages kept off the tunnel.
///
/// Nothing is pushed to the platform here, and that is deliberate. An excluded
/// set only takes effect when an interface is built, so this writes the
/// preference and the next `connect` carries it — which also means a change made
/// while the tunnel is up does nothing until it is rebuilt. The screen says so
/// rather than silently reconnecting: dropping someone's tunnel because they
/// ticked a checkbox is a worse surprise than a banner asking them to.
final class ExcludedAppsProvider
    extends $AsyncNotifierProvider<ExcludedApps, Set<String>> {
  /// The packages kept off the tunnel.
  ///
  /// Nothing is pushed to the platform here, and that is deliberate. An excluded
  /// set only takes effect when an interface is built, so this writes the
  /// preference and the next `connect` carries it — which also means a change made
  /// while the tunnel is up does nothing until it is rebuilt. The screen says so
  /// rather than silently reconnecting: dropping someone's tunnel because they
  /// ticked a checkbox is a worse surprise than a banner asking them to.
  ExcludedAppsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'excludedAppsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$excludedAppsHash();

  @$internal
  @override
  ExcludedApps create() => ExcludedApps();
}

String _$excludedAppsHash() => r'96f0af47e2b3f219d32995b74621b56292fbf486';

/// The packages kept off the tunnel.
///
/// Nothing is pushed to the platform here, and that is deliberate. An excluded
/// set only takes effect when an interface is built, so this writes the
/// preference and the next `connect` carries it — which also means a change made
/// while the tunnel is up does nothing until it is rebuilt. The screen says so
/// rather than silently reconnecting: dropping someone's tunnel because they
/// ticked a checkbox is a worse surprise than a banner asking them to.

abstract class _$ExcludedApps extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
