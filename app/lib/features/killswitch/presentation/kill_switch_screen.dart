import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../generated/l10n.dart';
import 'controller/kill_switch_controller.dart';

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

  Future<void> _openSystemSettings(BuildContext context, WidgetRef ref) async {
    final opened = await ref
        .read(killSwitchControllerProvider.notifier)
        .openSystemVpnSettings();
    if (!context.mounted || opened) return;
    showMessage(context, S.current.noVpnSettingsScreen, isError: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(S.current.killSwitchTitle)),
      body: ListView(
        padding: Gap.page,
        children: [
          _Card(
            title: S.current.reconnectTitle,
            body: S.current.reconnectBody,
            trailing: const _ActiveBadge(),
          ),
          Gap.md,
          _Card(
            title: S.current.blockTrafficTitle,
            body: S.current.blockTrafficBody,
            note: S.current.blockTrafficNote,
          ),
          SizedBox(height: 10.h),
          _Steps(
            steps: [
              S.current.stepOpenSettings,
              S.current.stepTapGear,
              S.current.stepTurnOnAlwaysOn,
              S.current.stepTurnOnBlockConnections,
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openSystemSettings(context, ref),
              icon: Icon(Icons.open_in_new, size: 18.r),
              label: Text(S.current.openSettingsButton),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            S.current.openSettingsHint,
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
  });

  final String title;
  final String body;
  final Widget? trailing;
  final String? note;

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
              if (trailing case final widget?) ...[
                SizedBox(width: 12.w),
                widget,
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: AppColors.textMuted,
              height: 1.4,
            ),
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
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: AppColors.warn,
                      height: 1.3,
                    ),
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
      child: content,
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
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textMuted,
                    ),
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

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            S.current.alwaysOn,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
