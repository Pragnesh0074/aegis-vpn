import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../tunnel_metrics.dart';

/// Live download and upload, side by side.
///
/// Two figures per direction on purpose. The rate answers "is anything moving
/// right now", which is what tells a person the tunnel is alive; the total
/// answers "how much has this session carried". Showing only the rate makes a
/// working but idle tunnel look broken.
class ThroughputPanel extends ConsumerWidget {
  const ThroughputPanel({super.key, required this.isUp});

  /// Zeroed rather than hidden while down, so the panel does not make the
  /// layout jump every time the tunnel goes up or comes back down.
  final bool isUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final throughput = ref.watch(throughputMeterProvider);

    return Row(
      children: [
        Expanded(
          child: _RateTile(
            label: 'Download',
            icon: Icons.south_rounded,
            bytesPerSecond: isUp ? throughput.downBytesPerSecond : 0,
            totalBytes: isUp ? throughput.downBytes : 0,
            tint: AppColors.accent,
            isUp: isUp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _RateTile(
            label: 'Upload',
            icon: Icons.north_rounded,
            bytesPerSecond: isUp ? throughput.upBytesPerSecond : 0,
            totalBytes: isUp ? throughput.upBytes : 0,
            tint: const Color(0xFF5B9DFF),
            isUp: isUp,
          ),
        ),
      ],
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.label,
    required this.icon,
    required this.bytesPerSecond,
    required this.totalBytes,
    required this.tint,
    required this.isUp,
  });

  final String label;
  final IconData icon;
  final double bytesPerSecond;
  final int totalBytes;
  final Color tint;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isUp ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  size: 12.r,
                  color: isUp ? tint : AppColors.textMuted,
                ),
              ),
              SizedBox(width: 7.w),
              // Two tiles share a 320pt-wide screen, and `minTextAdapt` holds
              // the label near its design size while the tile shrinks, so
              // "Download" beside its badge is the tightest row in the app.
              // Sized explicitly to fit there, and flexible so anything
              // narrower truncates instead of throwing an overflow.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Interpolated rather than snapped: the native counters arrive once a
          // second, and a number that jumps once a second reads as a glitch
          // while one that slides reads as a live meter. The tween is display
          // only — the endpoints are always the real samples.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: bytesPerSecond),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              Format.rate(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isUp ? AppColors.textHigh : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '${Format.bytes(totalBytes)} total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
