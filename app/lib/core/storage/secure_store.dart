import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_store.g.dart';

/// Thin wrapper over the platform keystore.
///
/// This is the only place in the app that touches `flutter_secure_storage`, which
/// matters because it holds two very different kinds of secret: session tokens,
/// and WireGuard private keys that by design never leave the device.
class SecureStore {
  const SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) {
  return const SecureStore(
    FlutterSecureStorage(
      // `first_unlock_this_device` keeps the key off iCloud Keychain backups: a
      // WireGuard private key must not be restorable onto a different phone.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      // The Android default is already AES-GCM with an RSA-wrapped keystore key.
      // The namespace keeps these entries separate from any other plugin's.
      aOptions: AndroidOptions(storageNamespace: 'aegis_vpn_secure'),
    ),
  );
}
