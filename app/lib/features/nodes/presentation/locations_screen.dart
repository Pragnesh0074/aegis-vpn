import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../tunnel/presentation/vpn_session.dart';
import '../domain/node_ranking.dart';
import 'nodes_providers.dart';
import 'selected_node.dart';
import 'widgets/location_tile.dart';

/// `GET /nodes`, read as a list of countries to appear from.
///
/// Picking one is not a preference the app stores and forgets: a WireGuard peer
/// belongs to a single node, so a change means revoking the current peer and
/// issuing a new one. [VpnSession.selectLocation] owns that, and does it now if
/// the tunnel is up or lazily on the next connect if it is not.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  Future<void> _select(BuildContext context, WidgetRef ref, String? nodeId) async {
    final ok = await ref.read(vpnSessionProvider.notifier).selectLocation(nodeId);
    if (!context.mounted) return;

    if (!ok) {
      final error = ref.read(vpnSessionProvider).error;
      showMessage(context, error == null ? 'Could not switch location' : describeError(error),
          isError: true);
      return;
    }
    // Back to the button, which is where the effect of the choice is visible.
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(vpnLocationsProvider);
    final selectedId = ref.watch(selectedNodeIdProvider).value;
    final busy = ref.watch(vpnSessionProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(vpnNodesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(vpnNodesProvider),
        child: AsyncView(
          value: locations,
          onRetry: () => ref.invalidate(vpnNodesProvider),
          data: (list) {
            if (list.isEmpty) return const _NoLocations();

            return ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              children: [
                _AutomaticTile(
                  selected: selectedId == null,
                  onTap: busy ? null : () => _select(context, ref, null),
                ),
                SizedBox(height: 8.h),
                const _AutomaticCaption(),
                SizedBox(height: 18.h),
                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
                  child: Text(
                    'ALL LOCATIONS',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                for (final location in list)
                  LocationTile(
                    location: location,
                    selected: selectedId != null &&
                        location.nodes.any((node) => node.id == selectedId),
                    onTap: busy
                        ? null
                        : () => _select(context, ref, location.preferred.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Let the app choose. The rule is the nearest node with capacity, estimated
/// from the device's time zone and tie-broken by load, so this row names the
/// node it currently resolves to rather than leaving the user to guess.
///
/// It reads "Closest", not "Fastest". Nothing here times anything — see
/// [NodeRanking] for why a client cannot — and a row promising speed while
/// ranking on geography would be the same lie the old copy told.
class _AutomaticTile extends ConsumerWidget {
  const _AutomaticTile({required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearest = ref.watch(nearestNodeProvider).value;

    return Material(
      color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.55)
                  : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.bolt_rounded, size: 21.r, color: AppColors.accent),
              ),
              SizedBox(width: 13.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Closest to you',
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHigh,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      nearest == null
                          ? 'Chosen by the server'
                          : '${nearest.name} · '
                              '${Format.percent(nearest.load.clamp(0, 1))} load',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 20.r, color: AppColors.accent)
              else
                Icon(Icons.chevron_right, size: 20.r, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says out loud what "closest" is based on.
///
/// Without it the row reads as a measurement. A person choosing a country
/// deserves to know the app worked this out from their clock and a table of
/// country centroids, so that a wrong answer — a phone still on last week's time
/// zone — is something they can recognise and override rather than trust.
class _AutomaticCaption extends StatelessWidget {
  const _AutomaticCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        'Estimated from your time zone, not measured. Pick a country below to '
        'override it.',
        style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted, height: 1.35),
      ),
    );
  }
}

class _NoLocations extends StatelessWidget {
  const _NoLocations();

  @override
  Widget build(BuildContext context) {
    // Reachable: the backend returns an empty list when no node row is seeded,
    // and connecting would then fail with a 503 rather than a 404.
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(48.r),
          child: Column(
            children: [
              Icon(Icons.public_off, size: 38.r, color: AppColors.textMuted),
              Gap.md,
              Text(
                'No exit servers are configured yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
