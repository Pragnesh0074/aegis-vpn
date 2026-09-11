import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/vpn_location.dart';

/// One country row on the locations screen.
///
/// A country, not a node. The fleet is addressed by node id underneath, but
/// "Germany" is the unit a person picks; which of two Frankfurt boxes they land
/// on is [VpnLocation.preferred]'s problem.
class LocationTile extends StatelessWidget {
  const LocationTile({
    super.key,
    required this.location,
    required this.selected,
    this.onTap,
  });

  final VpnLocation location;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = location.available && onTap != null;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
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
                LocationFlag(location: location, dimmed: !location.available),
                SizedBox(width: 13.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w600,
                          color: location.available
                              ? AppColors.textHigh
                              : AppColors.textMuted,
                        ),
                      ),
                      if (location.cityLine case final city?) ...[
                        SizedBox(height: 2.h),
                        Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
                        ),
                      ],
                      SizedBox(height: 8.h),
                      LoadBar(load: location.load, available: location.available),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 20.r, color: AppColors.accent)
                else if (!location.available)
                  Text(
                    'Full',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  )
                else
                  Icon(Icons.chevron_right, size: 20.r, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The country's flag, or a globe when the region did not parse to a country.
///
/// Regional-indicator emoji render as a flag on every platform that ships one
/// and degrade to the two letters where none exists, which is still a correct
/// answer — so there is no asset bundle here and no missing-image case.
class LocationFlag extends StatelessWidget {
  const LocationFlag({super.key, required this.location, this.dimmed = false});

  final VpnLocation location;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final flag = location.flag;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        width: 42.r,
        height: 42.r,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.outline),
        ),
        child: flag == null
            ? Icon(Icons.public, size: 19.r, color: AppColors.textMuted)
            : Text(flag, style: TextStyle(fontSize: 20.sp)),
      ),
    );
  }
}

/// How full a location is. Shared by the locations list and the summary card on
/// the connect screen, so the figure means the same thing in both places.
class LoadBar extends StatelessWidget {
  const LoadBar({super.key, required this.load, required this.available});

  final double load;
  final bool available;

  /// The bands are advisory: the backend refuses a peer only at 100%, but a
  /// nearly full node is worth steering away from before it gets there.
  static Color colorFor(double load) {
    if (load >= 0.9) return AppColors.danger;
    if (load >= 0.7) return AppColors.warn;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = load.clamp(0.0, 1.0);
    final color = available ? colorFor(clamped) : AppColors.danger;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.r),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4.h,
                color: color,
                backgroundColor: AppColors.outline,
              ),
            ),
          ),
        ),
        SizedBox(width: 9.w),
        Text(
          available ? '${Format.percent(clamped)} load' : 'At capacity',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
            color: available ? AppColors.textMuted : AppColors.danger,
          ),
        ),
      ],
    );
  }
}
