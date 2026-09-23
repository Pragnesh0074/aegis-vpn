import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/exit_check.dart';
import '../controller/exit_check_providers.dart';

/// Proof, rather than a claim.
///
/// The rest of the connect screen reports what this device believes about
/// itself. This row reports what a server on the other side of the connection
/// saw — the address the request actually arrived from — which is the only
/// statement on the screen a broken tunnel cannot fake.
///
/// It is also the only place a silent failure becomes visible. An interface can
/// be up, handshaking, and still not carrying a user's traffic if something on
/// the device has routed around it; every indicator would read green and this
/// one would not.
class ExitCheckCard extends ConsumerWidget {
  const ExitCheckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(exitCheckProvider);
    final carrying = ref.watch(tunnelCarryingProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: switch (check) {
        AsyncLoading() => const _Row(
          icon: Icons.travel_explore,
          tint: AppColors.textMuted,
          title: 'Checking where you appear…',
        ),
        // Not a blocker and not an alarm: failing to reach the API says nothing
        // about whether the tunnel is working, and dressing it up as a leak
        // would be its own kind of lie.
        AsyncError() => _Row(
          icon: Icons.help_outline,
          tint: AppColors.textMuted,
          title: 'Could not check your exit address',
          subtitle: 'The API was unreachable.',
          onRetry: () => ref.invalidate(exitCheckProvider),
        ),
        AsyncValue(value: final result?) => _Result(
          result: result,
          carrying: carrying,
          onRetry: () => ref.invalidate(exitCheckProvider),
        ),
      },
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.carrying,
    required this.onRetry,
  });

  final ExitCheck result;

  /// Whether the tunnel is up and handshaking, which decides whether a
  /// non-fleet address is a warning or simply the truth.
  final bool carrying;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final geo = result.geo;
    final flag = geo?.flag;
    final node = result.node;

    if (result.viaTunnel) {
      // `node` is set whenever `viaTunnel` is, since one is derived from the
      // other — but it is read as if it might not be, because a crash on the
      // connect screen is a worse way to find out the API changed shape.
      return _Row(
        icon: Icons.verified_user_outlined,
        tint: AppColors.accent,
        title: geo == null
            ? 'You appear as ${result.ip}'
            : 'You appear in ${geo.countryName}${flag == null ? '' : ' $flag'}',
        subtitle: node == null ? result.ip : '${result.ip} · ${node.name}',
        onRetry: onRetry,
      );
    }

    // The interface is up and handshaking, yet the request reached the API from
    // an address that is not ours. Either something is routing around the
    // tunnel, or this node egresses as an address its row does not list.
    if (carrying) {
      return _Row(
        icon: Icons.report_problem_outlined,
        tint: AppColors.warn,
        title: 'Your traffic is not exiting through Aegis',
        subtitle: 'Seen as ${result.ip}, which is not one of our servers.',
        onRetry: onRetry,
      );
    }

    return _Row(
      icon: Icons.public,
      tint: AppColors.textMuted,
      title: 'You appear as ${result.ip}',
      subtitle: 'Your real address. Connect to change it.',
      onRetry: onRetry,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    return Row(
      children: [
        Icon(icon, size: 19.r, color: tint),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: tint == AppColors.textMuted
                      ? AppColors.textHigh
                      : tint,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onRetry != null)
          IconButton(
            tooltip: 'Check again',
            onPressed: onRetry,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.refresh, size: 18.r, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
