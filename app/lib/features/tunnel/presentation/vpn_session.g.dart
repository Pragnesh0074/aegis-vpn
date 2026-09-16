// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device this phone can actually drive, or null if there is not one yet.
///
/// "Provisioned" means all three halves are present: the peer exists server-side
/// in `GET /devices`, its cached config is here, and its private key is in the
/// keystore. A device missing either local half appears in the account but
/// cannot be connected from this phone and is not a candidate — the private key
/// was never uploaded and the peer details are not re-issuable, so there is no
/// recovery, only re-provisioning.
///
/// `keepAlive`, and every `ref` call happens before the first `await`. Both are
/// load-bearing. Nothing *watches* this provider — `VpnSession` reads it — so as
/// an auto-dispose provider it was disposed while `GET /devices` was still in
/// flight, and the `ref.watch` after that await then threw
/// `UnmountedRefException`. That is why the first connect on a cold start failed
/// and the second, with the device list already cached, succeeded.

@ProviderFor(provisionedDevice)
final provisionedDeviceProvider = ProvisionedDeviceProvider._();

/// The device this phone can actually drive, or null if there is not one yet.
///
/// "Provisioned" means all three halves are present: the peer exists server-side
/// in `GET /devices`, its cached config is here, and its private key is in the
/// keystore. A device missing either local half appears in the account but
/// cannot be connected from this phone and is not a candidate — the private key
/// was never uploaded and the peer details are not re-issuable, so there is no
/// recovery, only re-provisioning.
///
/// `keepAlive`, and every `ref` call happens before the first `await`. Both are
/// load-bearing. Nothing *watches* this provider — `VpnSession` reads it — so as
/// an auto-dispose provider it was disposed while `GET /devices` was still in
/// flight, and the `ref.watch` after that await then threw
/// `UnmountedRefException`. That is why the first connect on a cold start failed
/// and the second, with the device list already cached, succeeded.

final class ProvisionedDeviceProvider
    extends $FunctionalProvider<AsyncValue<Device?>, Device?, FutureOr<Device?>>
    with $FutureModifier<Device?>, $FutureProvider<Device?> {
  /// The device this phone can actually drive, or null if there is not one yet.
  ///
  /// "Provisioned" means all three halves are present: the peer exists server-side
  /// in `GET /devices`, its cached config is here, and its private key is in the
  /// keystore. A device missing either local half appears in the account but
  /// cannot be connected from this phone and is not a candidate — the private key
  /// was never uploaded and the peer details are not re-issuable, so there is no
  /// recovery, only re-provisioning.
  ///
  /// `keepAlive`, and every `ref` call happens before the first `await`. Both are
  /// load-bearing. Nothing *watches* this provider — `VpnSession` reads it — so as
  /// an auto-dispose provider it was disposed while `GET /devices` was still in
  /// flight, and the `ref.watch` after that await then threw
  /// `UnmountedRefException`. That is why the first connect on a cold start failed
  /// and the second, with the device list already cached, succeeded.
  ProvisionedDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'provisionedDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$provisionedDeviceHash();

  @$internal
  @override
  $FutureProviderElement<Device?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Device?> create(Ref ref) {
    return provisionedDevice(ref);
  }
}

String _$provisionedDeviceHash() => r'756ea027f5c847a2353bde11d59ca7c144c225cc';

/// Connect, disconnect, and switch location — the whole of what the connect
/// screen can do.
///
/// This exists because the app no longer has an "add device" step. A person
/// taps one button and expects to be protected; issuing a WireGuard peer is
/// plumbing they should never have to know about. So this notifier provisions
/// on demand: on the first connect it generates a keypair, registers the public
/// half, caches the peer details, and only then brings the interface up.
///
/// Its own state is the progress of the *provisioning*, which is the slow and
/// failure-prone part. Whether the tunnel is up comes from
/// [tunnelStatusStreamProvider] as it always did, because the platform can take
/// the interface down without asking.

@ProviderFor(VpnSession)
final vpnSessionProvider = VpnSessionProvider._();

/// Connect, disconnect, and switch location — the whole of what the connect
/// screen can do.
///
/// This exists because the app no longer has an "add device" step. A person
/// taps one button and expects to be protected; issuing a WireGuard peer is
/// plumbing they should never have to know about. So this notifier provisions
/// on demand: on the first connect it generates a keypair, registers the public
/// half, caches the peer details, and only then brings the interface up.
///
/// Its own state is the progress of the *provisioning*, which is the slow and
/// failure-prone part. Whether the tunnel is up comes from
/// [tunnelStatusStreamProvider] as it always did, because the platform can take
/// the interface down without asking.
final class VpnSessionProvider
    extends $AsyncNotifierProvider<VpnSession, void> {
  /// Connect, disconnect, and switch location — the whole of what the connect
  /// screen can do.
  ///
  /// This exists because the app no longer has an "add device" step. A person
  /// taps one button and expects to be protected; issuing a WireGuard peer is
  /// plumbing they should never have to know about. So this notifier provisions
  /// on demand: on the first connect it generates a keypair, registers the public
  /// half, caches the peer details, and only then brings the interface up.
  ///
  /// Its own state is the progress of the *provisioning*, which is the slow and
  /// failure-prone part. Whether the tunnel is up comes from
  /// [tunnelStatusStreamProvider] as it always did, because the platform can take
  /// the interface down without asking.
  VpnSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vpnSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vpnSessionHash();

  @$internal
  @override
  VpnSession create() => VpnSession();
}

String _$vpnSessionHash() => r'f080e19da8d4b0bbbb9f86acfdbd47e2f2099813';

/// Connect, disconnect, and switch location — the whole of what the connect
/// screen can do.
///
/// This exists because the app no longer has an "add device" step. A person
/// taps one button and expects to be protected; issuing a WireGuard peer is
/// plumbing they should never have to know about. So this notifier provisions
/// on demand: on the first connect it generates a keypair, registers the public
/// half, caches the peer details, and only then brings the interface up.
///
/// Its own state is the progress of the *provisioning*, which is the slow and
/// failure-prone part. Whether the tunnel is up comes from
/// [tunnelStatusStreamProvider] as it always did, because the platform can take
/// the interface down without asking.

abstract class _$VpnSession extends $AsyncNotifier<void> {
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
