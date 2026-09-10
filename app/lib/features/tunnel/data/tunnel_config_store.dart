import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';
import '../../devices/domain/device_config.dart';

part 'tunnel_config_store.g.dart';

/// Caches the peer details the API issues exactly once.
///
/// `POST /devices` is the only endpoint that returns the node's public key and
/// endpoint; `GET /devices` deliberately omits them. Without a local copy the app
/// could never start a tunnel after the issue screen was dismissed, because it
/// would hold a private key with nothing to point it at.
///
/// Stored in the platform keystore rather than plain preferences. The contents
/// are not secrets in the cryptographic sense — the node's *public* key and a
/// public IP — but together they reveal which VPN a person uses and which exit
/// node they were assigned, which is exactly the metadata this product exists to
/// keep private. The private key stays where it was, in [DeviceKeyStore].
class TunnelConfigStore {
  const TunnelConfigStore(this._store);

  final SecureStore _store;

  static String _key(String deviceId) => 'aegis.tunnel.$deviceId.config';

  /// Device id whose tunnel the user last chose. Not "currently connected" —
  /// the platform owns that, and it can change without the app running.
  static const _selectedKey = 'aegis.tunnel.selectedDeviceId';

  Future<void> save(DeviceConfig config) {
    return _store.write(_key(config.deviceId), jsonEncode(config.toJson()));
  }

  /// Null when this device's peer was issued on another phone, or the app was
  /// reinstalled. Callers must treat that as "cannot connect", not as an error:
  /// the private key is gone too, so the only fix is issuing a new peer.
  Future<DeviceConfig?> read(String deviceId) async {
    final raw = await _store.read(_key(deviceId));
    if (raw == null) return null;
    try {
      return DeviceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // A config written by an older build whose shape has since changed. Drop
      // it rather than leaving the app permanently unable to parse its own cache.
      await _store.delete(_key(deviceId));
      return null;
    }
  }

  Future<void> delete(String deviceId) => _store.delete(_key(deviceId));

  Future<String?> readSelectedDeviceId() => _store.read(_selectedKey);

  Future<void> saveSelectedDeviceId(String deviceId) {
    return _store.write(_selectedKey, deviceId);
  }

  Future<void> clearSelectedDeviceId() => _store.delete(_selectedKey);
}

@Riverpod(keepAlive: true)
TunnelConfigStore tunnelConfigStore(Ref ref) {
  return TunnelConfigStore(ref.watch(secureStoreProvider));
}

/// The cached peer details for a device, or null when this phone did not issue it.
///
/// Backs reopening the config screen from the device list: without a cache hit
/// there is genuinely nothing to show, because the API will not re-issue the peer.
@riverpod
Future<DeviceConfig?> cachedDeviceConfig(Ref ref, String deviceId) {
  return ref.watch(tunnelConfigStoreProvider).read(deviceId);
}
