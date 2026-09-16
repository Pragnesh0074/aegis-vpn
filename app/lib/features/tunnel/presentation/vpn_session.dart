import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/failure_log.dart';
import '../../devices/data/device_key_store.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/data/wireguard_keygen.dart';
import '../../devices/domain/device.dart';
import '../../devices/presentation/devices_providers.dart';
import '../../nodes/presentation/nodes_providers.dart';
import '../../nodes/presentation/selected_node.dart';
import '../../profile/presentation/profile_providers.dart';
import '../data/tunnel_channel.dart';
import '../data/tunnel_config_store.dart';
import 'tunnel_controller.dart';

part 'vpn_session.g.dart';

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
@Riverpod(keepAlive: true)
Future<Device?> provisionedDevice(Ref ref) async {
  // Resolved up front: after an await, this provider may no longer be mounted
  // and touching `ref` is an error.
  final configStore = ref.watch(tunnelConfigStoreProvider);
  final keyStore = ref.watch(deviceKeyStoreProvider);

  final devices = await ref.watch(devicesProvider.future);
  if (devices.isEmpty) return null;

  Future<bool> isUsable(Device device) async {
    final config = await configStore.read(device.id);
    if (config == null) return false;
    return await keyStore.read(device.id) != null;
  }

  // The one last connected wins, so re-opening the app does not silently move
  // the user to a different peer than the one they were using.
  final preferredId = await configStore.readSelectedDeviceId();
  if (preferredId != null) {
    for (final device in devices) {
      if (device.id == preferredId && await isUsable(device)) return device;
    }
  }

  // Otherwise the newest usable one. `GET /devices` is oldest-first, and a
  // re-provision appends, so the newest is the one this phone just made.
  for (final device in devices.reversed) {
    if (await isUsable(device)) return device;
  }
  return null;
}

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
@riverpod
class VpnSession extends _$VpnSession {
  @override
  FutureOr<void> build() {}

  /// Brings up the tunnel, provisioning a peer first if this phone has none.
  Future<bool> connect() async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    final prepared = await AsyncValue.guard(_ensureDevice);
    if (prepared.hasError) {
      logFailure('provisioning a peer', prepared.error!, prepared.stackTrace!);
      state = AsyncError(prepared.error!, prepared.stackTrace!);
      return false;
    }
    state = const AsyncData(null);

    return ref.read(tunnelControllerProvider.notifier).connect(prepared.value!);
  }

  Future<bool> disconnect() {
    return ref.read(tunnelControllerProvider.notifier).disconnect();
  }

  /// What the connect button does, decided from what the tunnel is actually
  /// doing rather than from what the UI last drew.
  Future<bool> toggle() {
    final status = ref.read(tunnelStatusStreamProvider).value;
    final isUp = status != null && status.state.isUp;
    return isUp ? disconnect() : connect();
  }

  /// Points future connections at [nodeId] — null for automatic.
  ///
  /// A peer belongs to exactly one node, so changing location is not a setting
  /// but a re-issue: the old peer is revoked and a new one is issued on the
  /// chosen node. That is done lazily, on the next connect, unless the tunnel is
  /// up right now — in which case the user asked to move, and waiting would
  /// leave them looking at a country they are not in.
  Future<bool> selectLocation(String? nodeId) async {
    final current = await ref.read(selectedNodeIdProvider.future);
    await ref.read(selectedNodeIdProvider.notifier).select(nodeId);
    if (current == nodeId) return true;

    final status = ref.read(tunnelStatusStreamProvider).value;
    if (status == null || !status.state.isUp) return true;

    if (!await disconnect()) return false;
    return connect();
  }

  /// Returns the device id to connect, provisioning or re-provisioning as needed.
  Future<String> _ensureDevice() async {
    final wantedNodeId = await ref.read(selectedNodeIdProvider.future);
    final existing = await ref.read(provisionedDeviceProvider.future);

    if (existing != null) {
      if (wantedNodeId != null) {
        // A location the user picked is theirs to keep, even if it is having a
        // bad day. Moving someone out of the country they chose without asking
        // is worse than letting a connect fail with a reason.
        if (existing.node.id == wantedNodeId) return existing.id;
      } else if (await _nodeStillServing(existing.node.id)) {
        // Automatic keeps whatever node it already resolved to. Re-issuing on
        // every connect just to re-run the ranking would churn peers and burn
        // the device cap for no gain — and would move someone's exit country
        // under them because they crossed a time zone.
        return existing.id;
      }
    }

    // One peer per account, so provisioning always starts from a clean slate.
    //
    // Without this the account accumulates a peer per install: app data goes
    // with an uninstall, so the private key and cached config do too, and the
    // next connect cannot see the peer it is replacing. The old row stays
    // active, counts against the cap, and leaves an orphan on the node's
    // interface that can never handshake because nothing holds its key.
    //
    // This is a deliberate single-device policy, not a cleanup pass. When the
    // product supports a phone and a laptop on one account, this is the line to
    // change — scope it to peers this install can prove it owns, rather than
    // every peer on the account.
    await _releaseAll();

    // On automatic the app resolves the node itself and names it in the request.
    // Leaving `nodeId` off would hand the choice to `selectLeastLoaded()`, whose
    // rule is "emptiest with room" — which is how a user in Mumbai ended up in
    // Frankfurt the moment Frankfurt was quieter. See [NodeRanking].
    final automatic = wantedNodeId == null;
    return _provision(
      automatic ? await _rankedNodeId() : wantedNodeId,
      isEstimate: automatic,
    );
  }

  /// Whether the node this device sits on can still carry it.
  ///
  /// This is the failover. A peer belongs to exactly one node, so a node that
  /// has fallen over leaves every device on it unable to connect and unable to
  /// move — the app would keep re-establishing a tunnel to a box that is not
  /// answering, forever, because the config it holds is perfectly valid. Saying
  /// no here re-provisions on the next node the ranking picks.
  ///
  /// Two failures read as "keep going", deliberately. A fleet list that will not
  /// load is a network problem, not evidence that a node is dead, and revoking a
  /// working peer over a failed `GET /nodes` would be the app causing the outage
  /// it was trying to route around. A node that has vanished from the fleet
  /// entirely is the one case treated as gone, because it is.
  Future<bool> _nodeStillServing(String nodeId) async {
    try {
      final nodes = await ref.read(vpnNodesProvider.future);
      for (final node in nodes) {
        if (node.id == nodeId) return node.healthy;
      }
      return false;
    } catch (error, stack) {
      logFailure('checking the current node', error, stack);
      return true;
    }
  }

  /// The node automatic resolves to, or null when nothing can be ranked.
  ///
  /// A failure here is not a failure to connect: omitting `nodeId` falls back to
  /// the server's choice, which is worse than an estimate but still gets the user
  /// online. Being unable to connect because a node list did not load would be a
  /// far worse outcome than exiting from the wrong country.
  Future<String?> _rankedNodeId() async {
    try {
      final node = await ref.read(nearestNodeProvider.future);
      return node?.id;
    } catch (error, stack) {
      logFailure('ranking locations', error, stack);
      return null;
    }
  }

  /// Revokes every peer on the account and destroys any local halves held here.
  ///
  /// Best-effort per device: a node that is unreachable cannot have its peer
  /// removed from the live interface, and the API answers that with a 5xx. That
  /// must not stop the user connecting — being unable to get online because an
  /// unrelated node is down is a worse failure than a peer left behind — so each
  /// one is logged and the rest continue.
  Future<void> _releaseAll() async {
    final devices = await ref.read(devicesProvider.future);
    if (devices.isEmpty) return;

    final repository = ref.read(devicesRepositoryProvider);
    final keyStore = ref.read(deviceKeyStoreProvider);
    final configStore = ref.read(tunnelConfigStoreProvider);

    for (final device in devices) {
      try {
        await repository.revoke(device.id);
      } catch (error, stack) {
        logFailure('revoking the previous peer', error, stack);
      }
      // Local halves go regardless: the peer is either gone server-side or
      // unreachable, and in both cases the key here can never build a working
      // tunnel again.
      await keyStore.delete(device.id);
      await configStore.delete(device.id);
    }

    await configStore.clearSelectedDeviceId();
    _refresh();
  }

  /// Issues a peer, retrying without the estimate if the estimate is stale.
  ///
  /// [isEstimate] marks a node this app chose rather than one the user did. The
  /// fleet it was ranked against is cached, so the node can have been
  /// deactivated or filled since it was read — and when the user asked for
  /// automatic, "that node is gone" is not an answer worth showing them. A
  /// location they picked themselves does report the failure, because silently
  /// moving someone out of the country they chose is the worse outcome.
  Future<String> _provision(String? nodeId, {required bool isEstimate}) async {
    try {
      return await _register(nodeId);
    } on ApiException catch (error) {
      final stale = error.statusCode == 404 || error.statusCode == 503;
      if (!isEstimate || nodeId == null || !stale) rethrow;
      return _register(null);
    }
  }

  /// Generates a keypair and registers it, mirroring the order the old
  /// add-device flow used: the peer is revoked again if the local halves cannot
  /// be stored, because a peer with no private key on any device can never
  /// connect and still counts against the cap.
  Future<String> _register(String? nodeId) async {
    final keys = await ref.read(wireguardKeygenProvider).generate();
    final platform = ref.read(currentPlatformProvider);

    final config = await ref.read(devicesRepositoryProvider).create(
          publicKey: keys.publicKey,
          name: _autoName(platform, keys.publicKey),
          platform: platform.wireValue,
          nodeId: nodeId,
        );

    try {
      await ref.read(deviceKeyStoreProvider).save(config.deviceId, keys.privateKey);
      // `POST /devices` is the only call that returns the node's public key and
      // endpoint, so this cache is the difference between a tunnel that can be
      // restarted and one that can never be built again.
      await ref.read(tunnelConfigStoreProvider).save(config);
    } catch (_) {
      await ref
          .read(devicesRepositoryProvider)
          .revoke(config.deviceId)
          .catchError((_) {});
      rethrow;
    }

    _refresh();
    return config.deviceId;
  }

  /// The device list, the quota on the account screen, and the per-node load all
  /// change when a peer is issued or revoked.
  void _refresh() {
    ref
      ..invalidate(devicesProvider)
      ..invalidate(userProfileProvider)
      ..invalidate(vpnNodesProvider)
      ..invalidate(provisionedDeviceProvider);
  }

  /// A name for a device the user never named.
  ///
  /// The account screen still lists devices, and "Android device" three times
  /// over is useless there, so a short fingerprint of the public key is appended
  /// to tell them apart. The key is public — this leaks nothing.
  static String _autoName(DevicePlatform platform, String publicKey) {
    final fingerprint = publicKey.substring(0, 4);
    return '${platform.label} · $fingerprint';
  }
}
