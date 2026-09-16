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
import '../../killswitch/presentation/ad_block_controller.dart';
import '../../killswitch/presentation/kill_switch_controller.dart';
import '../../rewards/data/ad_ids.dart';
import '../../rewards/data/rewarded_ad_service.dart';
import '../../rewards/presentation/ad_block_grant_controller.dart';
import '../../splittunnel/presentation/split_tunnel_controller.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';
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
          onRetry: () => ref.invalidate(userProfileProvider),
          data: (data) => ListView(
            padding: Gap.page,
            children: [
              _IdentityCard(profile: data),
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

  static String _clock(Duration left) {
    final minutes = left.inMinutes;
    final seconds = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(adBlockControllerProvider.notifier).setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    final outcome =
        await ref.read(adBlockGrantControllerProvider.notifier).watchAdForTime();
    if (!context.mounted) return;

    switch (outcome) {
      case AdOutcome.earned:
        showMessage(context, 'Ads blocked for ${adBlockGrantWindow.inMinutes} more minutes.');
      // Closing an ad early is a choice, not a fault.
      case AdOutcome.dismissed:
        showMessage(context, 'Ad closed early — no time added.');
      case AdOutcome.unavailable:
        showMessage(context, 'No ad available right now. Try again shortly.', isError: true);
      case AdOutcome.failed:
        showMessage(context, 'That ad could not be shown. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(adBlockControllerProvider);
    final grant = ref.watch(adBlockGrantControllerProvider).value;

    final active = grant?.isActive ?? false;
    final watching = grant?.watching ?? false;

    return SettingsGroup(
      title: 'Privacy',
      children: [
        SettingsTile(
          label: 'Ad blocker',
          description: active
              ? 'Ads and trackers are being blocked.'
              : 'Watch a short ad to block ads and trackers for '
                  '${adBlockGrantWindow.inMinutes} minutes.',
          control: Switch(
            value: (setting.value ?? false) && active,
            // Nothing to turn off before an ad has bought any time, and a switch
            // that springs back is worse than one that will not move.
            onChanged:
                (setting.isLoading || !active) ? null : (v) => _toggle(context, ref, v),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active) ...[
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 15.r, color: AppColors.textHigh),
                    SizedBox(width: 5.w),
                    Text(
                      '${_clock(grant!.remaining)} left',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHigh,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: watching ? null : () => _watchAd(context, ref),
                  icon: watching
                      ? SizedBox(
                          width: 14.r,
                          height: 14.r,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.play_circle_outline, size: 18.r),
                  label: Text(
                    watching
                        ? 'Loading…'
                        : active
                            ? '+${adBlockGrantWindow.inMinutes} min'
                            : 'Watch ad',
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              const SettingsNote(
                text: 'Ads inside YouTube, Instagram and TikTok still show — they '
                    'come from the same address as the content.',
              ),
              if (AdIds.usingTestIds) ...[
                SizedBox(height: 6.h),
                const SettingsNote(text: 'Test ads: this build earns nothing.'),
              ],
            ],
          ),
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
    return SettingsTile(
      label: 'Apps outside the VPN',
      description: excluded == 0
          ? 'All apps go through the VPN.'
          : '$excluded app${excluded == 1 ? '' : 's'} bypass the VPN.',
      onTap: () => context.go(AppRoutes.splitTunnel),
    );
  }
}

// ── Connection ────────────────────────────────────────────────────────────────

class _ConnectionGroup extends ConsumerWidget {
  const _ConnectionGroup();

  Future<void> _autoConnect(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(autoConnectProvider.notifier).setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  Future<void> _killSwitch(BuildContext context, WidgetRef ref, bool enabled) async {
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

  Future<void> _addTile(BuildContext context, WidgetRef ref) async {
    final added = await ref.read(tunnelChannelProvider).requestAddTile();
    if (!context.mounted) return;
    showMessage(
      context,
      added ? 'Added to Quick Settings.' : 'Pull down the shade and edit the tiles.',
      isError: !added,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoConnect = ref.watch(autoConnectProvider).value?.enabled ?? false;
    final reconnect = ref.watch(killSwitchControllerProvider).value ?? false;
    // What the platform actually has armed, which can lag the stored setting.
    final armed = ref.watch(tunnelStatusStreamProvider).value?.killSwitch ?? false;

    return SettingsGroup(
      title: 'Connection',
      children: [
        SettingsTile(
          label: 'Auto-connect on public Wi-Fi',
          description: 'Connects when you join a network you have not trusted.',
          control: Switch(
            value: autoConnect,
            onChanged: (v) => _autoConnect(context, ref, v),
          ),
          footer: autoConnect
              ? const SettingsNote(
                  text: 'Works while the app is open. Android will not let an app '
                      'start a VPN on its own in the background.',
                )
              : null,
        ),
        SettingsTile(
          label: 'Reconnect if it drops',
          description: 'Brings the VPN back automatically after a lost connection.',
          control: Switch(
            value: reconnect,
            onChanged: (v) => _killSwitch(context, ref, v),
          ),
          footer: reconnect && !armed
              ? const SettingsNote(
                  text: 'Takes effect once the VPN has run at least once.',
                )
              : null,
        ),
        SettingsTile(
          label: 'Block traffic when VPN is off',
          description: 'An Android setting — only the system can do this.',
          onTap: () => _openSystemSettings(context, ref),
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
