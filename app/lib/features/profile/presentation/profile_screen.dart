import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../health/presentation/widgets/health_card.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';

/// `GET /users/me`, plus sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userProfileProvider.future),
        child: AsyncView(
          value: profile,
          onRetry: () => ref.invalidate(userProfileProvider),
          data: (data) => ListView(
            padding: Gap.page,
            children: [
              _IdentityCard(profile: data),
              Gap.md,
              _DeviceQuotaCard(profile: data),
              Gap.md,
              // The only way to reach the device list now that it is not a tab.
              // It is a maintenance screen: peers are issued by connecting, so
              // the reason to come here is to revoke one from a phone that is
              // gone and free the slot it still occupies.
              _NavRow(
                icon: Icons.devices_other,
                label: 'Devices',
                trailing: '${data.deviceCount}/${data.maxDevices}',
                onTap: () => context.go(AppRoutes.devices),
              ),
              Gap.md,
              const HealthCard(),
              Gap.lg,
              const _SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    profile.email.characters.first.toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                Gap.md,
                Expanded(
                  child: Text(profile.email, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            Gap.md,
            DetailRow(label: 'User ID', value: profile.id, monospace: true, copyable: true),
            DetailRow(label: 'Member since', value: Format.date(profile.createdAt)),
          ],
        ),
      ),
    );
  }
}

class _DeviceQuotaCard extends StatelessWidget {
  const _DeviceQuotaCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = profile.maxDevices == 0 ? 0.0 : profile.deviceCount / profile.maxDevices;

    return Card(
      child: Padding(
        padding: Gap.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices', style: theme.textTheme.titleSmall),
            Gap.sm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${profile.deviceCount}',
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  ' / ${profile.maxDevices}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Gap.sm,
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(value: used.clamp(0, 1), minHeight: 6.h),
            ),
            Gap.sm,
            Text(
              profile.hasDeviceCapacity
                  ? 'Room for ${profile.remainingDevices} more'
                  : 'Limit reached — remove one below before connecting a new phone',
              style: theme.textTheme.bodySmall?.copyWith(
                color: profile.hasDeviceCapacity
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable row in the account list, styled like the cards around it.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19.r, color: AppColors.textMuted),
              SizedBox(width: 14.w),
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              if (trailing case final value?)
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              SizedBox(width: 6.w),
              Icon(Icons.chevron_right, size: 19.r, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerStatefulWidget {
  const _SignOutButton();

  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  bool _busy = false;

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      // Revokes the refresh token via `POST /auth/logout`, then clears the
      // keystore. The router reacts to the session change on its own.
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (error) {
      if (mounted) showMessage(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _signOut,
      icon: const Icon(Icons.logout),
      label: Text(_busy ? 'Signing out…' : 'Sign out'),
    );
  }
}
