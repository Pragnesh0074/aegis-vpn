// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tunnel_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives connect and disconnect.
///
/// Deliberately does not hold the tunnel state: that comes from
/// [tunnelStatusStreamProvider], because the platform can take the tunnel down
/// without asking. This notifier's own state is only the progress of a command
/// the user issued, so a failed connect can show an error while the status card
/// keeps reporting what is actually true.

@ProviderFor(TunnelController)
final tunnelControllerProvider = TunnelControllerProvider._();

/// Drives connect and disconnect.
///
/// Deliberately does not hold the tunnel state: that comes from
/// [tunnelStatusStreamProvider], because the platform can take the tunnel down
/// without asking. This notifier's own state is only the progress of a command
/// the user issued, so a failed connect can show an error while the status card
/// keeps reporting what is actually true.
final class TunnelControllerProvider
    extends $AsyncNotifierProvider<TunnelController, void> {
  /// Drives connect and disconnect.
  ///
  /// Deliberately does not hold the tunnel state: that comes from
  /// [tunnelStatusStreamProvider], because the platform can take the tunnel down
  /// without asking. This notifier's own state is only the progress of a command
  /// the user issued, so a failed connect can show an error while the status card
  /// keeps reporting what is actually true.
  TunnelControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tunnelControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tunnelControllerHash();

  @$internal
  @override
  TunnelController create() => TunnelController();
}

String _$tunnelControllerHash() => r'852b323f3222d20cc0d2706fc71b3ee80b26dd47';

/// Drives connect and disconnect.
///
/// Deliberately does not hold the tunnel state: that comes from
/// [tunnelStatusStreamProvider], because the platform can take the tunnel down
/// without asking. This notifier's own state is only the progress of a command
/// the user issued, so a failed connect can show an error while the status card
/// keeps reporting what is actually true.

abstract class _$TunnelController extends $AsyncNotifier<void> {
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

/// True only when this specific device is the one carrying traffic.
///
/// The list shows a badge per device, and exactly one tunnel can be up at a time,
/// so each row needs to know whether it is the live one rather than just whether
/// *a* tunnel exists.

@ProviderFor(isDeviceConnected)
final isDeviceConnectedProvider = IsDeviceConnectedFamily._();

/// True only when this specific device is the one carrying traffic.
///
/// The list shows a badge per device, and exactly one tunnel can be up at a time,
/// so each row needs to know whether it is the live one rather than just whether
/// *a* tunnel exists.

final class IsDeviceConnectedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True only when this specific device is the one carrying traffic.
  ///
  /// The list shows a badge per device, and exactly one tunnel can be up at a time,
  /// so each row needs to know whether it is the live one rather than just whether
  /// *a* tunnel exists.
  IsDeviceConnectedProvider._({
    required IsDeviceConnectedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isDeviceConnectedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isDeviceConnectedHash();

  @override
  String toString() {
    return r'isDeviceConnectedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isDeviceConnected(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsDeviceConnectedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isDeviceConnectedHash() => r'181a15ec5c5441ddb1f233de8eb4ca3995a95c86';

/// True only when this specific device is the one carrying traffic.
///
/// The list shows a badge per device, and exactly one tunnel can be up at a time,
/// so each row needs to know whether it is the live one rather than just whether
/// *a* tunnel exists.

final class IsDeviceConnectedFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  IsDeviceConnectedFamily._()
    : super(
        retry: null,
        name: r'isDeviceConnectedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// True only when this specific device is the one carrying traffic.
  ///
  /// The list shows a badge per device, and exactly one tunnel can be up at a time,
  /// so each row needs to know whether it is the live one rather than just whether
  /// *a* tunnel exists.

  IsDeviceConnectedProvider call(String deviceId) =>
      IsDeviceConnectedProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'isDeviceConnectedProvider';
}
