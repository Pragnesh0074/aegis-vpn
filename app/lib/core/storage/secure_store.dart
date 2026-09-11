import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../error/app_exception.dart';

part 'secure_store.g.dart';

/// Thin wrapper over the platform keystore.
///
/// This is the only place in the app that touches `flutter_secure_storage`, which
/// matters because it holds two very different kinds of secret: session tokens,
/// and WireGuard private keys that by design never leave the device.
///
/// It does two things beyond forwarding calls, both of which exist because the
/// keystore is the app's least reliable local dependency:
///
/// Every operation is serialised. The Android plugin creates its wrapping key
/// lazily on first use, and concurrent access while that is happening can fail.
/// Several callers legitimately hit the store at once — the session tokens on
/// launch, the selected location, and one config plus one private key per
/// device the moment someone taps connect — so the overlap is real rather than
/// theoretical. Keystore reads are sub-millisecond, so a queue costs nothing.
///
/// And a keystore failure is translated into a [LocalException]. Left raw it
/// surfaces as a `PlatformException`, which nothing in the app recognises, so
/// it reached the user as the generic "Something went wrong" with no hint that
/// the keystore was the problem.
class SecureStore {
  SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Tail of the queue. Each operation chains onto it, so at most one keystore
  /// call is ever in flight.
  Future<void> _pending = Future<void>.value();

  Future<String?> read(String key) {
    return _run(() => _storage.read(key: key), 'read from');
  }

  Future<void> write(String key, String value) {
    return _run(() => _storage.write(key: key, value: value), 'write to');
  }

  Future<void> delete(String key) {
    return _run(() => _storage.delete(key: key), 'update');
  }

  Future<T> _run<T>(Future<T> Function() operation, String verb) {
    final result = Completer<T>();

    // The chained callback swallows every outcome into `result`, so a failed
    // operation cannot poison the queue for the ones behind it.
    _pending = _pending.then((_) async {
      try {
        result.complete(await operation());
      } on PlatformException catch (error, stack) {
        result.completeError(
          LocalException(
            'The device keystore could not be $verb. '
            '${error.message ?? 'The secure storage is unavailable.'}',
          ),
          stack,
        );
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });

    return result.future;
  }
}

@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) {
  return SecureStore(
    const FlutterSecureStorage(
      // `first_unlock_this_device` keeps the key off iCloud Keychain backups: a
      // WireGuard private key must not be restorable onto a different phone.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
      // The Android default is already AES-GCM with an RSA-wrapped keystore key.
      // The namespace keeps these entries separate from any other plugin's.
      aOptions: AndroidOptions(storageNamespace: 'aegis_vpn_secure'),
    ),
  );
}
