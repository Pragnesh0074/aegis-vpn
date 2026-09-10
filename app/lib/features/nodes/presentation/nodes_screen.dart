import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../domain/vpn_node.dart';
import 'nodes_providers.dart';
import 'widgets/node_tile.dart';

/// `GET /nodes` — the exit nodes this account can be issued a peer on.
class NodesScreen extends ConsumerWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(vpnNodesByRegionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(vpnNodesProvider),
        child: AsyncView(
          value: grouped,
          onRetry: () => ref.invalidate(vpnNodesProvider),
          data: (regions) {
            if (regions.isEmpty) return const _NoNodes();

            return ListView(
              padding: EdgeInsets.only(bottom: 24.h),
              children: [
                for (final entry in regions.entries)
                  _RegionSection(region: entry.key, nodes: entry.value),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RegionSection extends StatelessWidget {
  const _RegionSection({required this.region, required this.nodes});

  final String region;
  final List<VpnNode> nodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 4.h),
          child: Text(
            region.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.sp,
            ),
          ),
        ),
        for (final node in nodes) NodeTile(node: node),
      ],
    );
  }
}

class _NoNodes extends StatelessWidget {
  const _NoNodes();

  @override
  Widget build(BuildContext context) {
    // Reachable: the backend returns an empty list when no node row is seeded,
    // and `POST /devices` would then fail with 503 rather than 404.
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(48.r),
          child: Column(
            children: [
              Icon(Icons.dns_outlined, size: 40.r),
              Gap.md,
              Text(
                'No exit nodes are configured yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
