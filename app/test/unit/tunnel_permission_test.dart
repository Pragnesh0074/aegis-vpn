import 'package:aegis_vpn/features/devices/domain/device.dart';
import 'package:aegis_vpn/features/devices/domain/device_config.dart';
import 'package:aegis_vpn/features/tunnel/data/tunnel_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two permission failures arrive as the same `connect` rejection and differ
/// only by error code, so this is the seam where they can still be told apart.
/// Getting it wrong is not cosmetic: "tap connect again and allow it" sends
/// someone hunting for a dialog the OS has already refused to draw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('vpn.aegis/tunnel.test');
  const tunnel = TunnelChannel(methods: channel);

  final config = DeviceConfig(
    deviceId: 'd1',
    name: 'Phone',
    platform: DevicePlatform.android.wireValue,
    createdAt: DateTime.utc(2026),
    tunnelIp: '10.8.0.2/32',
    dns: '10.8.0.1',
    mtu: 1420,
    node: const DeviceNode(
      id: 'n1',
      name: 'Mumbai #1',
      region: 'in-mumbai',
    ),
    peer: const PeerConfig(
      publicKey: 'gsw8npeFnaTO+019dLZNo7ra6jVitQWEialU6kjwtDk=',
      endpoint: '3.111.32.212:51820',
      allowedIps: '0.0.0.0/0, ::/0',
      persistentKeepalive: 25,
    ),
  );

  void answerWith(String code, String message) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: code, message: message);
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  Future<TunnelException> connectError() async {
    try {
      await tunnel.connect(config: config, privateKey: 'k');
      fail('connect should have thrown');
    } on TunnelException catch (e) {
      return e;
    }
  }

  test('a dismissed consent dialog is a decline the user can retry', () async {
    answerWith('permission_denied', 'Permission to create a VPN connection was declined.');

    final error = await connectError();

    expect(error.isPermissionDenied, isTrue);
    expect(error.isPermissionUnavailable, isFalse);
  });

  test('a consent dialog that never appeared is not a decline', () async {
    answerWith(
      'permission_unavailable',
      'Another VPN app is active on this device.',
    );

    final error = await connectError();

    expect(error.isPermissionDenied, isFalse, reason: 'the user declined nothing');
    expect(error.isPermissionUnavailable, isTrue);
    // The platform knows which of several blockers applied; Dart must not
    // replace that with a generic string.
    expect(error.message, 'Another VPN app is active on this device.');
  });

  test('a consent request already in flight is neither failure', () async {
    answerWith('permission_pending', 'Android is already asking for VPN permission.');

    final error = await connectError();

    expect(error.isPermissionDenied, isFalse);
    expect(error.isPermissionUnavailable, isFalse);
  });
}
