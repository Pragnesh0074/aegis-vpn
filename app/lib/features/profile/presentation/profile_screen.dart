import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../auth/presentation/controller/auth_controller.dart';
import '../../killswitch/presentation/controller/ad_block_controller.dart';
import '../../splittunnel/presentation/controller/split_tunnel_controller.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../domain/user_profile.dart';
import 'controller/profile_providers.dart';
import 'widgets/settings_tile.dart';

/// The account page: who you are, every setting, and the way out.
///
/// The Protection page used to hold the switches. It was one tap away and full
/// of prose, which meant people who wanted to turn something on had to find a
/// page named after a concept rather than a thing. Everything now lives here,
/// one line of explanation each.
///
/// The short lines are not the whole truth about two of these, and the missing
/// part is kept as a [SettingsNote] rather than dropped: Android will not let an
/// app block traffic, and no DNS filter can strip ads that arrive from the same
/// address as the video. A switch that quietly implies otherwise is the one
/// thing this screen must not do.
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
          // A loader while it refetches, rather than the previous profile. Every
          // figure here moves together — entitlement, the trial countdown, the
          // lock on each setting — so keeping the old one on screen means the
          // page rewrites itself piece by piece as the new one lands.
          skipLoadingOnRefresh: false,
          onRetry: () => ref.invalidate(userProfileProvider),
          data: (data) => ListView(
            padding: Gap.page,
            children: [
              _IdentityCard(profile: data),
              Gap.md,
              _AccessCard(access: data.access),
              Gap.lg,
              const _PrivacyGroup(),
              Gap.lg,
              const _ConnectionGroup(),
              Gap.lg,
              const _MoreGroup(),
              Gap.lg,
              const _SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Privacy ───────────────────────────────────────────────────────────────────

class _PrivacyGroup extends ConsumerWidget {
  const _PrivacyGroup();

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref
          .read(adBlockControllerProvider.notifier)
          .setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted)
        showMessage(context, describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(adBlockControllerProvider);
    final entitled =
        ref.watch(userProfileProvider).value?.access.entitled ?? false;
    final enabled = (setting.value ?? false) && entitled;

    return SettingsGroup(
      title: 'Privacy',
      children: [
        SettingsTile(
          label: 'Ad blocker',
          description: entitled
              ? 'Blocks ad and tracker domains, in apps and the browser.'
              : 'Subscribe to block ads and trackers.',
          control: entitled
              ? Switch(
                  value: enabled,
                  // Nothing to toggle until the profile has loaded; moving it
                  // early would write a preference nobody has read.
                  onChanged: setting.isLoading
                      ? null
                      : (v) => _toggle(context, ref, v),
                )
              : const _LockedChip(),
          onTap: entitled ? null : () => context.go(AppRoutes.paywall),
          footer: enabled
              ? const SettingsNote(
                  text:
                      'Ads inside YouTube, Instagram and TikTok still show — they '
                      'come from the same address as the content.',
                )
              : null,
        ),
        const _SplitTunnelTile(),
      ],
    );
  }
}

class _SplitTunnelTile extends ConsumerWidget {
  const _SplitTunnelTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedAppsProvider).value?.length ?? 0;
    final entitled =
        ref.watch(userProfileProvider).value?.access.entitled ?? false;
    return SettingsTile(
      label: 'Split Tunnel',
      description: !entitled
          ? 'Subscribe to keep chosen apps off the VPN.'
          : excluded == 0
          ? 'All apps go through the VPN.'
          : '$excluded app${excluded == 1 ? '' : 's'} bypass the VPN.',
      control: entitled ? null : const _LockedChip(),
      onTap: () =>
          context.go(entitled ? AppRoutes.splitTunnel : AppRoutes.paywall),
    );
  }
}

/// Shown in place of a switch on a feature the account cannot currently use.
class _LockedChip extends StatelessWidget {
  const _LockedChip();

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

/// Where the account stands: on trial, subscribed, or locked out.
///
/// Its own card rather than a line on each setting, because the answer is the
/// same for all three and repeating it three times would read as three separate
/// problems.
class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.access});

  final AccessState access;

  @override
  Widget build(BuildContext context) {
    final (title, body, tint) = switch (access) {
      AccessState(subscribed: true) => (
        'Premium active',
        'Ad blocking, auto-reconnect and split tunnelling are yours.',
        AppColors.accent,
      ),
      AccessState(onTrial: true) => (
        'Free trial — ${access.hoursLeft}h left',
        'Everything is unlocked until then. After that the VPN stays free and '
            'the extras need a subscription.',
        AppColors.accent,
      ),
      _ => (
        'Trial ended',
        'The VPN still works. Ad blocking, auto-reconnect and split tunnelling '
            'need a subscription.',
        AppColors.warn,
      ),
    };

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textHigh,
            ),
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
          if (!access.subscribed) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.paywall),
                child: Text(access.onTrial ? 'See plans' : 'Subscribe'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Connection ────────────────────────────────────────────────────────────────

class _ConnectionGroup extends ConsumerWidget {
  const _ConnectionGroup();

  Future<void> _addTile(BuildContext context, WidgetRef ref) async {
    final added = await ref.read(tunnelChannelProvider).requestAddTile();
    if (!context.mounted) return;
    showMessage(
      context,
      added
          ? 'Added to Quick Settings.'
          : 'Pull down the shade and edit the tiles.',
      isError: !added,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      title: 'Connection',
      children: [
        SettingsTile(
          label: 'Kill switch',
          description: 'Always on — rebuilds the tunnel if it drops.',
          onTap: () => context.go(AppRoutes.killSwitch),
        ),
        SettingsTile(
          label: 'Quick Settings tile',
          description: 'Connect from the pull-down shade.',
          control: TextButton(
            onPressed: () => _addTile(context, ref),
            child: const Text('Add'),
          ),
        ),
      ],
    );
  }
}

// ── More ──────────────────────────────────────────────────────────────────────

class _MoreGroup extends StatelessWidget {
  const _MoreGroup();

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'More',
      children: [
        SettingsTile(
          label: 'Connection history',
          description: 'Past sessions, kept on this phone only.',
          onTap: () => context.go(AppRoutes.history),
        ),
      ],
    );
  }
}

// ── Identity + sign out ───────────────────────────────────────────────────────

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
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Gap.md,
                Expanded(
                  child: Text(
                    profile.email,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Gap.md,
            DetailRow(
              label: 'User ID',
              value: profile.id,
              monospace: true,
              copyable: true,
            ),
            DetailRow(
              label: 'Member since',
              value: Format.date(profile.createdAt),
            ),
          ],
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
