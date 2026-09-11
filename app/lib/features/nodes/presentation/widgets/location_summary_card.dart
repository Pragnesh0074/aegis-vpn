import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../domain/vpn_location.dart';
import '../selected_node.dart';
import 'location_tile.dart';

/// Where traffic is headed, on the connect screen, tappable through to the
/// locations list.
///
/// Always names a country, even on automatic: "Automatic" alone tells a person
/// nothing about where they appear to be, which is the one thing a VPN's front
/// screen has to answer. On automatic it shows the node the backend would most
/// likely pick, badged so the guess is not mistaken for a choice.
class LocationSummaryCard extends ConsumerWidget {
  const LocationSummaryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(locationChoiceProvider);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.outline),
          ),
          child: switch (choice) {
            AsyncLoading() => const _Message(text: 'Finding locations…', showSpinner: true),
            // A failed node list is not fatal — connecting omits `nodeId` and
            // lets the backend choose — so this reads as a line, not a blocker.
            AsyncError(:final error) => _Message(text: describeError(error)),
            AsyncValue(value: final choice?) => _Body(choice: choice),
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.choice});

  final LocationChoice choice;

  @override
  Widget build(BuildContext context) {
    final node = choice.node;
    if (node == null) {
      // The fleet is empty or entirely full. Connecting will fail with a 503,
      // so say so here rather than on the button.
      return const _Message(text: 'No exit servers are available right now');
    }

    final location = VpnLocation.group([node]).first;

    return Row(
      children: [
        LocationFlag(location: location),
        SizedBox(width: 13.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHigh,
                      ),
                    ),
                  ),
                  if (choice.isAutomatic) ...[
                    SizedBox(width: 7.w),
                    const _AutoBadge(),
                  ],
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                // The node's own name, not the city: on automatic this is the
                // only place the actual box is identified.
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
              ),
              SizedBox(height: 8.h),
              LoadBar(load: node.load, available: node.available),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Icon(Icons.chevron_right, size: 20.r, color: AppColors.textMuted),
      ],
    );
  }
}

class _AutoBadge extends StatelessWidget {
  const _AutoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        'AUTO',
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.showSpinner = false});

  final String text;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showSpinner) ...[
          SizedBox.square(
            dimension: 15.r,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12.w),
        ] else ...[
          Icon(Icons.public_off, size: 18.r, color: AppColors.textMuted),
          SizedBox(width: 12.w),
        ],
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
          ),
        ),
        Icon(Icons.chevron_right, size: 20.r, color: AppColors.textMuted),
      ],
    );
  }
}
