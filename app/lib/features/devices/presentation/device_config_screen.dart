import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/detail_row.dart';
import '../../tunnel/presentation/widgets/tunnel_card.dart';
import '../domain/device.dart';
import '../domain/device_config.dart';
import 'devices_providers.dart';

/// The full peer config returned by `POST /devices`, shown once.
///
/// It cannot be re-fetched: `GET /devices` withholds the node's public key and
/// endpoint. The private key is read from the keystore here and combined with the
/// server's half only in the rendered `wg-quick` file — the two never meet in a
/// request.
class DeviceConfigScreen extends ConsumerWidget {
  const DeviceConfigScreen({super.key, required this.config, this.isNew = false});

  final DeviceConfig config;

  /// True right after issue, when the "save this now" warning is worth showing.
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final privateKey = ref.watch(devicePrivateKeyProvider(config.deviceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(config.name),
        actions: [
          IconButton(
            tooltip: 'Copy wg-quick config',
            onPressed: privateKey.value == null
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: config.toWgQuick(privateKey: privateKey.requireValue!),
                      ),
                    );
                    if (context.mounted) {
                      showMessage(context, 'Config copied to clipboard');
                    }
                  },
            icon: const Icon(Icons.copy_all),
          ),
        ],
      ),
      body: ListView(
        padding: Gap.page,
        children: [
          if (isNew) const _IssuedBanner(),
          if (isNew) Gap.md,
          TunnelCard(deviceId: config.deviceId),
          Gap.md,
          _Section(
            title: 'Interface',
            subtitle: 'This device',
            children: [
              DetailRow(label: 'Device', value: config.name),
              DetailRow(
                label: 'Platform',
                value: DevicePlatform.labelFor(config.platform),
              ),
              DetailRow(label: 'Address', value: config.tunnelIp, monospace: true, copyable: true),
              DetailRow(label: 'DNS', value: config.dns, monospace: true),
              DetailRow(label: 'MTU', value: '${config.mtu}'),
              DetailRow(label: 'Issued', value: Format.dateTime(config.createdAt)),
              _PrivateKeyRow(privateKey: privateKey),
            ],
          ),
          Gap.md,
          _Section(
            title: 'Peer',
            subtitle: '${config.node.name} · ${config.node.region}',
            children: [
              DetailRow(
                label: 'Public key',
                value: config.peer.publicKey,
                monospace: true,
                copyable: true,
              ),
              DetailRow(
                label: 'Endpoint',
                value: config.peer.endpoint,
                monospace: true,
                copyable: true,
              ),
              DetailRow(label: 'Allowed IPs', value: config.peer.allowedIps, monospace: true),
              DetailRow(
                label: 'Keepalive',
                value: '${config.peer.persistentKeepalive}s',
              ),
            ],
          ),
          Gap.md,
          if (privateKey.value != null)
            _WgQuickBlock(text: config.toWgQuick(privateKey: privateKey.requireValue!))
          else
            Card(
              child: Padding(
                padding: Gap.page,
                child: Text(
                  'The private key for this device is not on this phone, so a '
                  'complete config cannot be shown. Remove the device and add a '
                  'new one to get a working tunnel.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssuedBanner extends StatelessWidget {
  const _IssuedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: Gap.page,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.vpn_key_outlined, color: theme.colorScheme.onPrimaryContainer),
          Gap.md,
          Expanded(
            child: Text(
              'Peer issued. Save this config now — the server will not return the '
              'peer details again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The private key is masked until asked for. It is the one value on this screen
/// that must never be shoulder-surfed or screenshotted casually.
class _PrivateKeyRow extends StatefulWidget {
  const _PrivateKeyRow({required this.privateKey});

  final AsyncValue<String?> privateKey;

  @override
  State<_PrivateKeyRow> createState() => _PrivateKeyRowState();
}

class _PrivateKeyRowState extends State<_PrivateKeyRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final key = widget.privateKey.value;

    if (widget.privateKey.isLoading) {
      return const DetailRow(label: 'Private key', value: 'Reading keystore…');
    }
    if (key == null) {
      return const DetailRow(label: 'Private key', value: 'Not on this device');
    }

    return Row(
      children: [
        Expanded(
          child: DetailRow(
            label: 'Private key',
            value: _revealed ? key : '•' * 24,
            monospace: true,
            copyable: _revealed,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18.r,
          tooltip: _revealed ? 'Hide' : 'Reveal',
          onPressed: () => setState(() => _revealed = !_revealed),
          icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ],
    );
  }
}

class _WgQuickBlock extends StatelessWidget {
  const _WgQuickBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('wg-quick config', style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) showMessage(context, 'Config copied');
                  },
                  icon: Icon(Icons.copy, size: 16.r),
                  label: const Text('Copy'),
                ),
              ],
            ),
            Gap.sm,
            // Horizontally scrollable: base64 keys are wider than any phone.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                text,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.sm,
            ...children,
          ],
        ),
      ),
    );
  }
}
