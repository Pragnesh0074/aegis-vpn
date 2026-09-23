import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/device_key_store.dart';
import '../../data/devices_repository.dart';
import '../../domain/device.dart';

part 'devices_providers.g.dart';

/// `GET /devices` — the account's active peers.
@Riverpod(keepAlive: true)
Future<List<Device>> devices(Ref ref) =>
    ref.watch(devicesRepositoryProvider).list();

/// The private key for one device, or null if this phone does not hold it.
///
/// A device issued on another phone, or one whose key was lost to a reinstall,
/// still appears in `GET /devices` — the server has the public half. There is no
/// way to recover the private key, so the UI has to say so rather than pretend.
@riverpod
Future<String?> devicePrivateKey(Ref ref, String deviceId) {
  return ref.watch(deviceKeyStoreProvider).read(deviceId);
}

/// The platform value to send as `CreateDeviceDto.platform`.
///
/// Only the five values in `PLATFORMS` are accepted; anything else is a 400.
@riverpod
DevicePlatform currentPlatform(Ref ref) {
  if (kIsWeb) return DevicePlatform.linux;
  if (Platform.isAndroid) return DevicePlatform.android;
  if (Platform.isIOS) return DevicePlatform.ios;
  if (Platform.isMacOS) return DevicePlatform.macos;
  if (Platform.isWindows) return DevicePlatform.windows;
  return DevicePlatform.linux;
}
