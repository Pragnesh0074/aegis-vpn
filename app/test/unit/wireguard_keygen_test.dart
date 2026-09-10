import 'dart:convert';

import 'package:aegis_vpn/features/devices/data/wireguard_keygen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const keygen = WireguardKeygen();

  test('produces keys the backend regex accepts', () async {
    final wgKey = RegExp(r'^[A-Za-z0-9+/]{43}=$');

    // Generate several: base64 of 32 bytes is always 44 chars, but clamping fixes
    // specific bits, and a bug there would only show on some draws.
    for (var i = 0; i < 20; i++) {
      final pair = await keygen.generate();
      expect(wgKey.hasMatch(pair.publicKey), isTrue, reason: pair.publicKey);
      expect(wgKey.hasMatch(pair.privateKey), isTrue, reason: pair.privateKey);
      expect(base64Decode(pair.publicKey), hasLength(32));
      expect(base64Decode(pair.privateKey), hasLength(32));
    }
  });

  test('private key is clamped exactly as wg genkey clamps it', () async {
    final pair = await keygen.generate();
    final bytes = base64Decode(pair.privateKey);

    // X25519 clamping: clear the low 3 bits of byte 0, clear bit 7 and set bit 6
    // of byte 31. `wg genkey` applies the same mask, so a key that fails this
    // would not round-trip through a real WireGuard implementation.
    expect(bytes[0] & 0x07, 0);
    expect(bytes[31] & 0x80, 0);
    expect(bytes[31] & 0x40, 0x40);
  });

  test('each call yields a distinct keypair', () async {
    final keys = <String>{};
    for (var i = 0; i < 10; i++) {
      keys.add((await keygen.generate()).privateKey);
    }
    expect(keys, hasLength(10));
  });
}
