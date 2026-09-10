import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/error/app_exception.dart';

part 'wireguard_keygen.g.dart';

/// A WireGuard keypair, base64-encoded exactly as `wg genkey` / `wg pubkey` emit it.
class WireguardKeyPair {
  const WireguardKeyPair({required this.privateKey, required this.publicKey});

  /// Never leaves the device. Written to the keystore, put in the local
  /// `[Interface]` section, and nowhere else.
  final String privateKey;

  /// The only half that is uploaded, as `CreateDeviceDto.publicKey`.
  final String publicKey;
}

/// Generates the device's tunnel identity.
///
/// This is the security invariant the whole design rests on: the private key is
/// created here, on the device, and the API only ever sees the public half. A
/// server that never holds a private key cannot hand one over or leak one.
class WireguardKeygen {
  const WireguardKeygen();

  /// `[A-Za-z0-9+/]{43}=` — the same anchored regex the backend enforces in
  /// `wg-validation.ts`. Checked locally so a bad key fails before a round trip.
  static final _wgKey = RegExp(r'^[A-Za-z0-9+/]{43}=$');

  Future<WireguardKeyPair> generate() async {
    try {
      // X25519 with a 32-byte seed. The implementation clamps the scalar before
      // storing it, so these bytes are byte-identical to what `wg genkey` writes
      // and the derived public key matches `wg pubkey`.
      final keyPair = await X25519().newKeyPair();
      final privateBytes = await keyPair.extractPrivateKeyBytes();
      final publicBytes = (await keyPair.extractPublicKey()).bytes;

      final pair = WireguardKeyPair(
        privateKey: base64Encode(privateBytes),
        publicKey: base64Encode(publicBytes),
      );

      // A malformed key would be rejected by the API with a 400 that reads like a
      // client bug. Failing here says plainly where it went wrong.
      if (!_wgKey.hasMatch(pair.publicKey) || !_wgKey.hasMatch(pair.privateKey)) {
        throw const LocalException('Generated an invalid WireGuard key.');
      }
      return pair;
    } on LocalException {
      rethrow;
    } catch (error) {
      throw LocalException('Could not generate a WireGuard key: $error');
    }
  }
}

@Riverpod(keepAlive: true)
WireguardKeygen wireguardKeygen(Ref ref) => const WireguardKeygen();
