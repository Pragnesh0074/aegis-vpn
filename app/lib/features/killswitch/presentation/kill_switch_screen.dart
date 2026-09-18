import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../tunnel/data/tunnel_channel.dart';
import 'kill_switch_controller.dart';

/// Everything that keeps traffic off the open internet when the tunnel is not up.
///
/// Two halves, and they are not the same thing — which is the reason this has its
/// own screen rather than two rows on the account page. Aegis can rebuild a
/// tunnel that dropped. Only Android can refuse to carry traffic while it is
/// down, and no app may turn that on for itself, so the second half is a set of
/// directions rather than a switch.
///
/// Saying so plainly matters: "kill switch" in most VPN apps means the second
/// thing, and a user who reads the first as the second believes they are covered
/// when the app is closed — precisely when they are not.
class KillSwitchScreen extends ConsumerWidget {
  const KillSwitchScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(killSwitchControllerProvider.notifier).setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  Future<void> _openSystemSettings(BuildContext context, WidgetRef ref) async {
    final opened =
        await ref.read(killSwitchControllerProvider.notifier).openSystemVpnSettings();
    if (!context.mounted || opened) return;
    showMessage(context, 'No VPN settings screen on this device.', isError: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitled = ref.watch(userProfileProvider).value?.access.entitled ?? false;
    final reconnect = (ref.watch(killSwitchControllerProvider).value ?? false) && entitled;
    // What the platform actually has armed, which can lag the stored setting.
    final armed = ref.watch(tunnelStatusStreamProvider).value?.killSwitch ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Kill switch')),
      body: ListView(
        padding: Gap.page,
        children: [
          _Card(
            title: 'Reconnect if it drops',
            body: 'If the tunnel goes down without you asking — a lost network, '
                'the system reclaiming the VPN — Aegis brings it straight back, '
                'up to five times with a growing delay.',
            trailing: entitled
                ? Switch(
                    value: reconnect,
                    onChanged: (v) => _toggle(context, ref, v),
                  )
                : const _Locked(),
            onTap: entitled ? null : () => context.go(AppRoutes.paywall),
            note: switch ((entitled, reconnect, armed)) {
              (false, _, _) => 'Subscribe to turn this on.',
              (true, true, false) =>
                'Saved, but not armed on this device yet. It takes effect once '
                    'the VPN service has run at least once.',
              _ => null,
            },
          ),
          Gap.md,
          _Card(
            title: 'Block traffic while the VPN is off',
            body: 'This one is not ours to switch. Android will not let an app '
                'block the whole device\'s traffic — only the system can, and it '
                'is the only thing that covers you after a reboot or once Aegis '
                'has been swiped away.',
            note: 'Without it, traffic uses your normal connection whenever the '
                'tunnel is down.',
          ),
          SizedBox(height: 10.h),
          _Steps(
            steps: const [
              'Open Android\'s VPN settings with the button below.',
              'Tap the gear next to Aegis.',
              'Turn on "Always-on VPN".',
              'Turn on "Block connections without VPN".',
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openSystemSettings(context, ref),
              icon: Icon(Icons.open_in_new, size: 18.r),
              label: const Text('Open Android VPN settings'),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Some phones bury this under Settings → Connections → More → VPN.',
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    this.trailing,
    this.note,
    this.onTap,
  });

  final String title;
  final String body;
  final Widget? trailing;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
              if (trailing case final widget?) ...[SizedBox(width: 12.w), widget],
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            body,
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          if (note case final text?) ...[
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13.r, color: AppColors.warn),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 11.5.sp, color: AppColors.warn, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18.r),
              child: content,
            ),
    );
  }
}

/// Numbered directions for the part Android owns.
class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20.r,
                  height: 20.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.textHigh,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 15.r, color: AppColors.textMuted),
        SizedBox(width: 4.w),
        Text(
          'Premium',
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
