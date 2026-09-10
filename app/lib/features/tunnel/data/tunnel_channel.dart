import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../devices/domain/device_config.dart';
import '../domain/tunnel_status.dart';

part 'tunnel_channel.g.dart';

/// Raised when the platform refuses to start a tunnel.
///
/// Separate from a generic PlatformException so the UI can tell the one case a
/// person can fix — declining the system VPN consent dialog — from the ones they
/// cannot.
class TunnelException implements Exception {
  const TunnelException(this.message, {this.isPermissionDenied = false});

  final String message;

  /// True when the OS consent prompt was dismissed. Retrying is meaningful.
  final bool isPermissionDenied;

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
  }) async {
    try {
      await _methods.invokeMethod<void>('connect', {
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
}

@Riverpod(keepAlive: true)
TunnelChannel tunnelChannel(Ref ref) => const TunnelChannel();

/// Platform-pushed status, the single source of truth for whether traffic is
/// actually being tunnelled.
@Riverpod(keepAlive: true)
Stream<TunnelStatus> tunnelStatusStream(Ref ref) {
  return ref.watch(tunnelChannelProvider).watch();
}
