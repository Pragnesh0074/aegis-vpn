import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';

/// One setting: a name, one line saying what it does, and a control.
///
/// Every setting on the account page uses it, so they line up and read as one
/// list rather than a pile of differently shaped cards. The description is
/// deliberately one line — the long explanations that used to fill the
/// Protection page made people scroll past the switches they came for.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    required this.description,
    this.control,
    this.footer,
    this.onTap,
  });

  final String label;

  /// One short sentence. If it needs two, it probably needs its own screen.
  final String description;

  /// Usually a [Switch] or a button. Null for a tappable row.
  final Widget? control;

  /// Shown under the description — a countdown, or a caveat that would be
  /// dishonest to leave out.
  final Widget? footer;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
                if (footer case final extra?) ...[SizedBox(height: 8.h), extra],
              ],
            ),
          ),
          if (control case final widget?) ...[SizedBox(width: 12.w), widget],
          if (onTap != null && control == null) ...[
            SizedBox(width: 8.w),
            Icon(Icons.chevron_right, size: 19.r, color: AppColors.textMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// A titled group of [SettingsTile]s in one bordered card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.outline),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A short caveat under a setting. Small and muted, but never omitted: these
/// are the sentences that stop a switch promising something it cannot do.
class SettingsNote extends StatelessWidget {
  const SettingsNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 13.r, color: AppColors.textMuted),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted, height: 1.3),
          ),
        ),
      ],
    );
  }
}
