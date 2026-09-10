import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/device.dart';
import '../domain/device_config.dart';

part 'devices_repository.g.dart';

/// Talks to `backend/src/devices/devices.controller.ts`.
class DevicesRepository {
  const DevicesRepository(this._api);

  final ApiClient _api;

  /// `GET /devices` — the user's active peers, oldest first. Revoked devices are
  /// excluded server-side.
  Future<List<Device>> list() async {
    final rows = await _api.getList(ApiEndpoints.devices);
    return rows.map(Device.fromJson).toList(growable: false);
  }

  /// `POST /devices` — registers a public key and issues a WireGuard peer.
  ///
  /// [publicKey] must be the *public* half. The matching private key stays on the
  /// device; sending it here would defeat the entire design.
  ///
  /// [nodeId] is optional: omitted, the backend picks the least-loaded node with
  /// capacity. Expect a 409 when the device cap is reached and a 503 when the
  /// whole fleet is full.
  Future<DeviceConfig> create({
    required String publicKey,
    required String name,
    required String platform,
    String? nodeId,
  }) async {
    final json = await _api.postJson(
      ApiEndpoints.devices,
      body: {
        'publicKey': publicKey,
        'name': name,
        'platform': platform,
        // The DTO uses `forbidNonWhitelisted`, so a null `nodeId` would be
        // rejected outright rather than treated as absent. Omit the key instead.
        'nodeId': ?nodeId,
      },
    );
    return DeviceConfig.fromJson(json);
  }

  /// `DELETE /devices/:id` → 204. Idempotent, and scoped to the caller: another
  /// user's device is indistinguishable from one that does not exist.
  Future<void> revoke(String deviceId) => _api.delete(ApiEndpoints.device(deviceId));
}

@Riverpod(keepAlive: true)
DevicesRepository devicesRepository(Ref ref) {
  return DevicesRepository(ref.watch(apiClientProvider));
}
