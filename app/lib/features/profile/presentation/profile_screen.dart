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
import '../../autoconnect/presentation/auto_connect_controller.dart';
import '../../killswitch/presentation/kill_switch_controller.dart';
import '../../splittunnel/presentation/split_tunnel_controller.dart';
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
              // No device list and no quota. An account holds exactly one peer
              // — connecting revokes whatever came before it — so a list of one
              // row that cannot be acted on, above a bar reading "1 of 5", would
              // describe a product that does not exist yet. The screen and its
              // route are still here for when it does; see `_ensureDevice` in
              // `vpn_session.dart`, which is the policy that has to change first.
              const _ProtectionRow(),
              Gap.md,
              const _SplitTunnelRow(),
              Gap.md,
              _NavRow(
                icon: Icons.history,
                label: 'History',
                onTap: () => context.go(AppRoutes.history),
              ),
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

class _SplitTunnelRow extends ConsumerWidget {
  const _SplitTunnelRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedAppsProvider).value?.length ?? 0;
    return _NavRow(
      icon: Icons.call_split,
      label: 'Split tunnelling',
      trailing: excluded == 0 ? 'All apps' : '$excluded excluded',
      onTap: () => context.go(AppRoutes.splitTunnel),
    );
  }
}

/// One row for both of the settings on the protection page, because a person
/// looking for either is looking for the same thing: does this stay on.
class _ProtectionRow extends ConsumerWidget {
  const _ProtectionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final killSwitch = ref.watch(killSwitchControllerProvider).value ?? false;
    final autoConnect = ref.watch(autoConnectProvider).value?.enabled ?? false;

    final on = [
      if (autoConnect) 'Auto-connect',
      if (killSwitch) 'Kill switch',
    ];

    return _NavRow(
      icon: Icons.shield_outlined,
      label: 'Protection',
      trailing: on.isEmpty ? 'Off' : on.join(' · '),
      onTap: () => context.go(AppRoutes.protection),
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
