import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_providers.dart';

/// The paywall, and a DUMMY checkout behind it.
///
/// No money changes hands and the server verifies nothing — `POST
/// /users/me/subscription` grants a month to whoever asks. It exists so the flow
/// can be walked end to end before a payment provider is chosen, and every part
/// of it that a real integration would replace is marked as such on screen, so
/// nobody ships this believing it takes payments.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;
  _Plan _selected = _Plan.monthly;

  Future<void> _checkout() async {
    setState(() => _busy = true);
    try {
      // The pause is theatre, not work: a checkout that returns instantly reads
      // as "nothing happened". The real one will be slower than this.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await ref.read(profileRepositoryProvider).subscribe(_selected.id);
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      showMessage(context, 'Subscribed. Everything is unlocked.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(userProfileProvider).value?.access;

    return Scaffold(
      appBar: AppBar(title: const Text('Aegis Premium')),
      body: ListView(
        padding: Gap.page,
        children: [
          Text(
            access?.onTrial ?? false
                ? 'Your free trial has ${access!.hoursLeft} hours left.'
                : 'Your free trial has ended.',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Subscribe to keep ad blocking, the kill switch and split tunnelling. '
            'The VPN itself stays free.',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted, height: 1.4),
          ),
          Gap.lg,
          for (final plan in _Plan.values)
            _PlanCard(
              plan: plan,
              selected: plan == _selected,
              onTap: _busy ? null : () => setState(() => _selected = plan),
            ),
          Gap.md,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _checkout,
              child: _busy
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Subscribe — ${_selected.price}'),
            ),
          ),
          Gap.md,
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.warn),
            ),
            child: Text(
              'DEMO — no payment is taken and no card is asked for. This button '
              'grants 30 days to anyone who taps it.',
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.warn, height: 1.35),
            ),
          ),
          if (access?.subscribed ?? false) ...[
            Gap.md,
            TextButton(
              onPressed: _busy ? null : _cancel,
              child: const Text('Cancel subscription (demo)'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).cancelSubscription();
      ref.invalidate(userProfileProvider);
      if (mounted) showMessage(context, 'Subscription cleared.');
    } catch (error) {
      if (mounted) showMessage(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Placeholder pricing, but the plan is real: it is sent to the API, which grants
/// 30 days or 365 accordingly. A paywall that offers a year and quietly writes a
/// month only reveals the disagreement in the database.
enum _Plan {
  monthly('monthly', 'Monthly', '₹149 / month', 'Billed every month. Cancel any time.'),
  yearly('yearly', 'Yearly', '₹1,199 / year', 'Two months free compared with monthly.');

  const _Plan(this.id, this.label, this.price, this.blurb);

  /// Sent to the API, which decides the duration. The names must match `PLANS`.
  final String id;

  final String label;
  final String price;
  final String blurb;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  final _Plan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 19.r,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.price,
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHigh,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        plan.blurb,
                        style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
