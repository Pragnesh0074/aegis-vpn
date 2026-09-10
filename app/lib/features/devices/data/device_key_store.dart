import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/secure_store.dart';

part 'device_key_store.g.dart';

/// Holds each device's WireGuard private key in the platform keystore, keyed by
/// the device id the API assigned.
///
/// Separate from the session store because the lifetime is different: a private
/// key outlives any number of sign-ins and must be destroyed at exactly one
/// moment — when its peer is revoked server-side.
class DeviceKeyStore {
  const DeviceKeyStore(this._store);

  final SecureStore _store;

  static String _key(String deviceId) => 'aegis.device.$deviceId.privateKey';

  Future<void> save(String deviceId, String privateKey) {
    return _store.write(_key(deviceId), privateKey);
  }

  /// Null when the key is gone — a reinstall, or a device issued on another phone.
  /// The config screen degrades to showing the peer half only.
  Future<String?> read(String deviceId) => _store.read(_key(deviceId));

  Future<void> delete(String deviceId) => _store.delete(_key(deviceId));
}

@Riverpod(keepAlive: true)
DeviceKeyStore deviceKeyStore(Ref ref) => DeviceKeyStore(ref.watch(secureStoreProvider));
