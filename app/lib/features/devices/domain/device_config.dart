import 'device.dart';

/// Mirrors `DeviceConfigResponse` from `backend/src/devices/device.response.ts` —
/// everything needed to build a WireGuard config *except* the private key.
///
/// Returned only by `POST /devices`, at the moment a peer is issued. It is not
/// re-fetchable: `GET /devices` deliberately omits the node's public key and
/// endpoint. That is why the app persists the private key locally and shows this
/// screen once.
class DeviceConfig {
  const DeviceConfig({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.createdAt,
    required this.tunnelIp,
    required this.dns,
    required this.mtu,
    required this.node,
    required this.peer,
  });

  final String deviceId;
  final String name;
  final String platform;
  final DateTime createdAt;

  /// The client's own `[Interface] Address`. Always a `/32`.
  final String tunnelIp;

  /// Resolver inside the tunnel — Unbound on the node, so DNS never leaves it.
  final String dns;
  final int mtu;

  final DeviceNode node;
  final PeerConfig peer;

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tunnelIp: json['tunnelIp'] as String,
      dns: json['dns'] as String,
      mtu: (json['mtu'] as num).toInt(),
      node: DeviceNode.fromJson(json['node'] as Map<String, dynamic>),
      peer: PeerConfig.fromJson(json['peer'] as Map<String, dynamic>),
    );
  }

  /// Round-trips through [DeviceConfig.fromJson], so a config the API issued once
  /// can be cached on the device and replayed to start a tunnel later.
  ///
  /// Deliberately excludes the private key, which this object never holds.
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'platform': platform,
        'createdAt': createdAt.toIso8601String(),
        'tunnelIp': tunnelIp,
        'dns': dns,
        'mtu': mtu,
        'node': node.toJson(),
        'peer': peer.toJson(),
      };

  /// Renders a `wg-quick` config file.
  ///
  /// [privateKey] is read from the keystore by the caller and is never held on
  /// this object — keeping it out of the model is what stops it being logged or
  /// serialised along with the rest of the response.
  String toWgQuick({required String privateKey}) {
    return '''
[Interface]
PrivateKey = $privateKey
Address = $tunnelIp
DNS = $dns
MTU = $mtu

[Peer]
PublicKey = ${peer.publicKey}
Endpoint = ${peer.endpoint}
AllowedIPs = ${peer.allowedIps}
PersistentKeepalive = ${peer.persistentKeepalive}
''';
  }
}

class PeerConfig {
  const PeerConfig({
    required this.publicKey,
    required this.endpoint,
    required this.allowedIps,
    required this.persistentKeepalive,
  });

  /// The *server's* WireGuard public key. Safe to hold — the node's private key
  /// never leaves the node.
  final String publicKey;

  /// `host:port`, the UDP endpoint the tunnel dials.
  final String endpoint;

  /// `0.0.0.0/0, ::/0` — full tunnel. IPv6 is included so it is blackholed rather
  /// than leaking around the tunnel.
  final String allowedIps;

  /// 25s. Mandatory on mobile: carrier NAT drops an idle tunnel after 30-60s.
  final int persistentKeepalive;

  factory PeerConfig.fromJson(Map<String, dynamic> json) {
    return PeerConfig(
      publicKey: json['publicKey'] as String,
      endpoint: json['endpoint'] as String,
      allowedIps: json['allowedIps'] as String,
      persistentKeepalive: (json['persistentKeepalive'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'publicKey': publicKey,
        'endpoint': endpoint,
        'allowedIps': allowedIps,
        'persistentKeepalive': persistentKeepalive,
      };
}
