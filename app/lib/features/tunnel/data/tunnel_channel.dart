import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../devices/domain/device_config.dart';
import '../../splittunnel/domain/installed_app.dart';
import '../domain/tunnel_status.dart';

part 'tunnel_channel.g.dart';

/// Raised when the platform refuses to start a tunnel.
///
/// Separate from a generic PlatformException so the UI can tell the cases a
/// person can act on from the ones they cannot — and, among those, tell the two
/// permission failures apart. They look identical from Dart but need opposite
/// advice: one asks the user to tap connect again, the other tells them that
/// tapping again will achieve nothing.
class TunnelException implements Exception {
  const TunnelException(
    this.message, {
    this.isPermissionDenied = false,
    this.isPermissionUnavailable = false,
  });

  final String message;

  /// True when the OS consent prompt was shown and dismissed. Retrying is
  /// meaningful: the prompt will appear again.
  final bool isPermissionDenied;

  /// True when the prompt never appeared, because the OS refused to show it —
  /// another VPN holds the always-on slot, VPN access for this app is blocked,
  /// or the ROM has no consent activity at all. Retrying changes nothing, so the
  /// message has to name what to go and fix. [message] carries the platform's
  /// own wording, which is more specific than anything Dart can infer.
  final bool isPermissionUnavailable;

  @override
  String toString() => message;
}

/// The Dart half of the VPN platform channel.
///
/// Commands go over a MethodChannel; state comes back on an EventChannel rather
/// than by polling, because the tunnel can go down without the app asking — the
/// OS reclaiming the interface, another VPN taking over, or the user revoking
/// permission from Settings.
class TunnelChannel {
  const TunnelChannel({
    MethodChannel methods = const MethodChannel('vpn.aegis/tunnel'),
    EventChannel events = const EventChannel('vpn.aegis/tunnel/status'),
  })  : _methods = methods,
        _events = events;

  final MethodChannel _methods;
  final EventChannel _events;

  /// Every state change the platform reports, including ones the app did not ask
  /// for. The native side emits the current status on subscribe, so a listener
  /// does not have to call [status] first.
  Stream<TunnelStatus> watch() {
    return _events.receiveBroadcastStream().map((event) {
      return TunnelStatus.fromJson(Map<String, dynamic>.from(event as Map));
    });
  }

  Future<TunnelStatus> status() async {
    final raw = await _methods.invokeMapMethod<String, dynamic>('status');
    if (raw == null) return TunnelStatus.disconnected;
    return TunnelStatus.fromJson(raw);
  }

  /// Brings the interface up.
  ///
  /// [privateKey] is passed per-call and never cached natively: the native layer
  /// hands it straight to the WireGuard backend. Keeping the keystore as the only
  /// durable home for it means uninstalling the app destroys it.
  Future<void> connect({
    required DeviceConfig config,
    required String privateKey,
    List<String> excludedApps = const [],
  }) async {
    try {
      await _methods.invokeMethod<void>('connect', {
        'excludedApps': excludedApps,
        'deviceId': config.deviceId,
        'name': config.name,
        'privateKey': privateKey,
        'address': config.tunnelIp,
        'dns': config.dns,
        'mtu': config.mtu,
        'peerPublicKey': config.peer.publicKey,
        'endpoint': config.peer.endpoint,
        'allowedIps': config.peer.allowedIps,
        'persistentKeepalive': config.peer.persistentKeepalive,
      });
    } on PlatformException catch (e) {
      throw TunnelException(
        e.message ?? 'The tunnel could not be started.',
        isPermissionDenied: e.code == 'permission_denied',
        // 'permission_pending' is deliberately neither: a consent dialog is
        // already up, so there is nothing for the user to do but answer it.
        isPermissionUnavailable: e.code == 'permission_unavailable',
      );
    }
  }

  Future<void> disconnect() async {
    try {
      await _methods.invokeMethod<void>('disconnect');
    } on PlatformException catch (e) {
      throw TunnelException(e.message ?? 'The tunnel could not be stopped.');
    }
  }

  /// Arms or disarms the platform's rebuild-on-drop behaviour.
  ///
  /// The flag lives natively because the drops worth surviving are the ones
  /// where this isolate is not running. It does not block traffic while the
  /// tunnel is down — only Android can, via [openVpnSettings].
  Future<void> setKillSwitch({required bool enabled}) async {
    try {
      await _methods.invokeMethod<void>('setKillSwitch', {'enabled': enabled});
    } on PlatformException catch (e) {
      throw TunnelException(e.message ?? 'The kill switch could not be changed.');
    }
  }

  /// Every launcher-visible app on the device, for the split-tunnel picker.
  ///
  /// Empty on a platform that does not implement it, rather than throwing: a
  /// picker with nothing in it is a screen that explains itself, while an
  /// exception here would take the settings page down with it.
  Future<List<InstalledApp>> listApps() async {
    try {
      final raw = await _methods.invokeListMethod<Object?>('listApps');
      return (raw ?? const [])
          .map((row) => InstalledApp.fromJson(Map<String, dynamic>.from(row! as Map)))
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }




  /// Tells the platform its connect request has been acted on.
  ///
  /// The request outlives the app deliberately, so something has to spend it.
  /// Acknowledged on the attempt rather than on success: a request that keeps
  /// failing would otherwise be retried for as long as the app stayed open.
  Future<void> ackConnectRequest() async {
    try {
      await _methods.invokeMethod<void>('ackConnectRequest');
    } on PlatformException {
      // Nothing useful to do. The next request supersedes this one.
    } on MissingPluginException {
      // No platform implementation; there was nothing to acknowledge.
    }
  }



  /// Asks Android to offer the user the Quick Settings tile.
  ///
  /// False when the device declined, the user declined, or the platform is older
  /// than Android 13 — where a tile exists but can only be added by hand.
  Future<bool> requestAddTile() async {
    try {
      return await _methods.invokeMethod<bool>('requestAddTile') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens Android's VPN settings, where "Block connections without VPN" lives.
  ///
  /// That switch is the only thing that actually stops traffic when no tunnel is
  /// up, and Android does not let an app enable it for itself — so this hands the
  /// user to the right screen instead of pretending to do it for them.
  ///
  /// False when the device has no VPN settings activity to open, which some OEM
  /// builds genuinely do not.
  Future<bool> openVpnSettings() async {
    try {
      return await _methods.invokeMethod<bool>('openVpnSettings') ?? false;
    } on PlatformException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
TunnelChannel tunnelChannel(Ref ref) => const TunnelChannel();

/// Platform-pushed status, the single source of truth for whether traffic is
/// actually being tunnelled.
@Riverpod(keepAlive: true)
Stream<TunnelStatus> tunnelStatusStream(Ref ref) {
  return ref.watch(tunnelChannelProvider).watch();
}
