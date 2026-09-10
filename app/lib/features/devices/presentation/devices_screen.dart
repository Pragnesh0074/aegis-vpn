import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/data/tunnel_config_store.dart';
import '../domain/device.dart';
import 'add_device_sheet.dart';
import 'device_config_screen.dart';
import 'devices_controller.dart';
import 'devices_providers.dart';
import 'widgets/device_tile.dart';

/// `GET /devices`, with add and revoke.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final config = await AddDeviceSheet.show(context);
    if (config == null || !context.mounted) return;

    // Straight to the config: this is the only time the server returns the peer's
    // public key and endpoint.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceConfigScreen(config: config, isNew: true),
      ),
    );
  }

  /// Reopens the config issued for [device].
  ///
  /// Only this phone can have it: `GET /devices` withholds the peer details and
  /// the private key never left the keystore. A miss means the peer was issued
  /// elsewhere or the app was reinstalled, and no amount of retrying will fix it.
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
            'here. Remove it and add a new device to connect from this phone.',
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

  Future<void> _remove(BuildContext context, WidgetRef ref, Device device) async {
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

    final removed = await ref.read(devicesControllerProvider.notifier).removeDevice(device.id);
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

    // The backend enforces the cap with a 409; disabling the button just makes
    // that outcome visible before the user fills in a form.
    final atCapacity = profile.value?.hasDeviceCapacity == false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          if (profile.value case final p?)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Text(
                  '${p.deviceCount}/${p.maxDevices}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atCapacity ? null : () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(atCapacity ? 'Limit reached' : 'Add device'),
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
              // Clears the extended FAB so the last row is never trapped behind it.
              padding: EdgeInsets.only(bottom: 96.h),
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
    final theme = Theme.of(context);
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(48.r),
          child: Column(
            children: [
              Icon(Icons.devices_other, size: 40.r),
              Gap.md,
              Text('No devices yet', style: theme.textTheme.titleSmall),
              Gap.xs,
              Text(
                'Adding one generates a WireGuard keypair here and registers only '
                'the public half with the server.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
