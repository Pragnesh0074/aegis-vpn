import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../wifi_notice_watcher.dart';

/// "You joined a network that is not trusted, and Aegis connected because of it."
///
/// The in-app half of the notice the notification carries — shown when the app
/// happens to be open, where a notification is the wrong place to look.
///
/// It reports rather than asks. Auto-connect has already brought the tunnel up
/// by the time this appears, and that ordering is deliberate: asking first would
/// mean sitting unprotected on an unknown network while a dialog waits for
/// someone who may not be looking at their phone. So the offer is to stop doing
/// it here in future, not to decide whether to do it now.
class UntrustedWifiBanner extends ConsumerWidget {
  const UntrustedWifiBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssid = ref.watch(wifiNoticeWatcherProvider);
    if (ssid == null) return const SizedBox.shrink();

    final notifier = ref.read(wifiNoticeWatcherProvider.notifier);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_tethering, size: 17.r, color: AppColors.accent),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Connected on $ssid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'It is not a trusted network, so Aegis turned on by itself. Trust it '
            'to disconnect and leave this network alone from now on.',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.dismiss(trust: ssid),
                  child: const Text('Trust & disconnect'),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  onPressed: () => notifier.dismiss(),
                  child: const Text('Stay protected'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
