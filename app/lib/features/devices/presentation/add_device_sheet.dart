import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../nodes/domain/vpn_node.dart';
import '../../nodes/presentation/nodes_providers.dart';
import '../../nodes/presentation/widgets/node_tile.dart';
import '../domain/device.dart';
import '../domain/device_config.dart';
import 'devices_controller.dart';
import 'devices_providers.dart';

/// Collects the three things `POST /devices` needs beyond the generated key:
/// a name, a platform, and optionally a node.
///
/// Returns the issued [DeviceConfig] so the caller can show it once.
class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({super.key});

  static Future<DeviceConfig?> show(BuildContext context) {
    return showModalBottomSheet<DeviceConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddDeviceSheet(),
    );
  }

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  DevicePlatform? _platform;

  /// Null means "let the backend choose" — it picks the least-loaded node with
  /// capacity, which is the right default for almost everyone.
  String? _nodeId;

  @override
  void initState() {
    super.initState();
    _platform = ref.read(currentPlatformProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final config = await ref.read(devicesControllerProvider.notifier).addDevice(
          name: _name.text,
          platform: _platform!.wireValue,
          nodeId: _nodeId,
        );

    if (!mounted || config == null) return;
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(devicesControllerProvider);
    final nodes = ref.watch(vpnNodesProvider);

    ref.listen(devicesControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showMessage(context, describeError(error), isError: true);
      }
    });

    return Padding(
      // Lifts the sheet above the keyboard while the name field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: Gap.page,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a device', style: theme.textTheme.titleLarge),
              Gap.xs,
              Text(
                'A keypair is generated on this device. Only the public key is '
                'uploaded — the private key never leaves the phone.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Gap.lg,
              TextFormField(
                controller: _name,
                validator: Validators.deviceName,
                textCapitalization: TextCapitalization.words,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  hintText: 'Pixel 9',
                ),
              ),
              Gap.sm,
              DropdownButtonFormField<DevicePlatform>(
                initialValue: _platform,
                decoration: const InputDecoration(labelText: 'Platform'),
                items: [
                  for (final platform in DevicePlatform.values)
                    DropdownMenuItem(value: platform, child: Text(platform.label)),
                ],
                onChanged: (value) => setState(() => _platform = value),
                validator: (value) => value == null ? 'Pick a platform' : null,
              ),
              Gap.md,
              Text('Server', style: theme.textTheme.titleSmall),
              Gap.xs,
              _NodePicker(
                nodes: nodes,
                selectedId: _nodeId,
                onSelected: (id) => setState(() => _nodeId = id),
              ),
              Gap.lg,
              FilledButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? SizedBox.square(
                        dimension: 20.r,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate key and add'),
              ),
              Gap.sm,
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePicker extends StatelessWidget {
  const _NodePicker({
    required this.nodes,
    required this.selectedId,
    required this.onSelected,
  });

  final AsyncValue<List<VpnNode>> nodes;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return nodes.when(
      loading: () => Padding(
        padding: EdgeInsets.all(16.r),
        child: const Center(child: CircularProgressIndicator()),
      ),
      // A failed node list is not fatal: omitting `nodeId` lets the backend
      // choose, so the device can still be added.
      error: (error, _) => Text(
        '${describeError(error)}\nThe server will be chosen automatically.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      // One RadioGroup ancestor owns the selection; the tiles only declare their
      // value. A full node is rendered but not selectable — the backend would
      // refuse it with a 503.
      data: (list) => RadioGroup<String?>(
        groupValue: selectedId,
        onChanged: onSelected,
        child: Column(
          children: [
            const RadioListTile<String?>(
              value: null,
              title: Text('Automatic'),
              subtitle: Text('Least-loaded server with capacity'),
              contentPadding: EdgeInsets.zero,
            ),
            for (final node in list)
              RadioListTile<String?>(
                value: node.id,
                enabled: node.available,
                title: Text(node.name),
                subtitle: NodeLoadLine(node: node),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
