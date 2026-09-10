import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_view.dart';
import '../health_providers.dart';

/// `GET /health` — API and database reachability.
class HealthCard extends ConsumerWidget {
  const HealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final health = ref.watch(healthStatusProvider);

    return Card(
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('API status', style: theme.textTheme.titleSmall)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18.r,
                  tooltip: 'Check again',
                  onPressed: () => ref.invalidate(healthStatusProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            switch (health) {
              AsyncLoading() => Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: LinearProgressIndicator(minHeight: 3.h),
                ),
              // A failure here is the expected shape when the API is down — show
              // it as a status line, not as a full error page.
              AsyncError(:final error) => _StatusLine(
                  label: describeError(error),
                  healthy: false,
                ),
              AsyncValue(:final value?) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLine(
                      label: value.isHealthy ? 'Operational' : 'Degraded',
                      healthy: value.isHealthy,
                    ),
                    Text(
                      'Database ${value.database} · '
                      'up ${Format.duration(value.uptimeSeconds)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.healthy});

  final String label;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = healthy ? theme.colorScheme.primary : theme.colorScheme.error;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Gap.sm,
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
