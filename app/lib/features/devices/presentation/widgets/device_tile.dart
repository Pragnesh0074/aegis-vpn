import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/device.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device, this.onTap, this.onRemove});

  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  static IconData iconFor(String platform) {
    return switch (DevicePlatform.tryParse(platform)) {
      DevicePlatform.android => Icons.phone_android,
      DevicePlatform.ios => Icons.phone_iphone,
      DevicePlatform.macos => Icons.laptop_mac,
      DevicePlatform.windows => Icons.desktop_windows_outlined,
      DevicePlatform.linux => Icons.terminal,
      null => Icons.devices_other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(iconFor(device.platform), size: 20.r),
      ),
      title: Text(device.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${device.tunnelIp} · ${device.node.name}'),
          Text(
            'Last seen ${Format.lastSeen(device.lastSeenAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove device',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
      isThreeLine: true,
    );
  }
}
