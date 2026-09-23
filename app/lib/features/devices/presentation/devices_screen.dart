import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../profile/presentation/controller/profile_providers.dart';
import '../../tunnel/data/tunnel_config_store.dart';
import '../domain/device.dart';
import 'device_config_screen.dart';
import 'controller/devices_controller.dart';
import 'controller/devices_providers.dart';
import 'widgets/device_tile.dart';

/// `GET /devices`, with revoke.
///
/// There is no add button. Connecting provisions a peer on its own now (see
/// `VpnSession`), so the only thing left to do here is get rid of one — a peer
/// issued on a phone the user no longer has, which still counts against the
/// device cap and can only be freed from this screen.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  /// Reopens the config issued for [device].
  ///
  /// Only the phone that issued it can have it: `GET /devices` withholds the
  /// peer details and the private key never left the keystore. A miss means the
  /// peer was issued elsewhere or the app was reinstalled, and no amount of
  /// retrying will fix it.
  Future<void> _open(BuildContext context, WidgetRef ref, Device device) async {
    final config = await ref.read(cachedDeviceConfigProvider(device.id).future);
    if (!context.mounted) return;

    if (config == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(device.name),
          content: const Text(
            'This device was set up on another phone, so its keys are not stored '
            'here. Remove it to free a slot, then connect from this phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DeviceConfigScreen(config: config)),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Device device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${device.name}?'),
        content: const Text(
          'The peer is revoked on the server and this device stops connecting. '
          'Its private key is deleted from this phone and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removed = await ref
        .read(devicesControllerProvider.notifier)
        .removeDevice(device.id);
    if (context.mounted && removed) {
      showMessage(context, '${device.name} removed');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final profile = ref.watch(userProfileProvider);

    ref.listen(devicesControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showMessage(context, describeError(error), isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          if (profile.value case final p?)
            Padding(
              padding: EdgeInsets.only(right: 18.w),
              child: Center(
                child: Text(
                  '${p.deviceCount}/${p.maxDevices}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: p.hasDeviceCapacity
                        ? AppColors.textMuted
                        : AppColors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(devicesProvider)
            ..invalidate(userProfileProvider);
        },
        child: AsyncView(
          value: devices,
          onRetry: () => ref.invalidate(devicesProvider),
          data: (list) {
            if (list.isEmpty) return const _NoDevices();

            return ListView.separated(
              padding: EdgeInsets.only(bottom: 24.h),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final device = list[index];
                return DeviceTile(
                  device: device,
                  onTap: () => _open(context, ref, device),
                  onRemove: () => _remove(context, ref, device),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NoDevices extends StatelessWidget {
  const _NoDevices();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(48.r),
          child: Column(
            children: [
              Icon(Icons.devices_other, size: 38.r, color: AppColors.textMuted),
              Gap.md,
              Text(
                'No devices yet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHigh,
                ),
              ),
              Gap.xs,
              Text(
                'One is registered automatically the first time you connect. A '
                'keypair is generated here and only the public half is uploaded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
