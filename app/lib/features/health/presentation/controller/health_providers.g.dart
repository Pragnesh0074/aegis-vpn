// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// API reachability, shown on the account screen.
///
/// Not `keepAlive`: this is only meaningful while someone is looking at it, and
/// the value goes stale immediately.

@ProviderFor(healthStatus)
final healthStatusProvider = HealthStatusProvider._();

/// API reachability, shown on the account screen.
///
/// Not `keepAlive`: this is only meaningful while someone is looking at it, and
/// the value goes stale immediately.

final class HealthStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<HealthStatus>,
          HealthStatus,
          FutureOr<HealthStatus>
        >
    with $FutureModifier<HealthStatus>, $FutureProvider<HealthStatus> {
  /// API reachability, shown on the account screen.
  ///
  /// Not `keepAlive`: this is only meaningful while someone is looking at it, and
  /// the value goes stale immediately.
  HealthStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthStatusHash();

  @$internal
  @override
  $FutureProviderElement<HealthStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HealthStatus> create(Ref ref) {
    return healthStatus(ref);
  }
}

String _$healthStatusHash() => r'c2e74e8ddb078d19115451babcee7cbbcaca8db8';
