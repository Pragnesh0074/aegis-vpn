import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../killswitch/presentation/ad_block_controller.dart';
import '../../killswitch/presentation/kill_switch_controller.dart';
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

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(adBlockControllerProvider.notifier).setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(adBlockControllerProvider);
    final enabled = setting.value ?? false;

    return SettingsGroup(
      title: 'Privacy',
      children: [
        SettingsTile(
          label: 'Ad blocker',
          description: 'Refuses ad and tracker domains at the server, in the '
              'browser and inside apps.',
          control: Switch(
            value: enabled,
            // Nothing to toggle until the profile has loaded; moving it early
            // would write a preference nobody has read.
            onChanged: setting.isLoading ? null : (v) => _toggle(context, ref, v),
          ),
          footer: enabled
              ? const SettingsNote(
                  text: 'Ads inside YouTube, Instagram and TikTok still show — they '
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
    final reconnect = ref.watch(killSwitchControllerProvider).value ?? false;
    // What the platform actually has armed, which can lag the stored setting.
    final armed = ref.watch(tunnelStatusStreamProvider).value?.killSwitch ?? false;

    return SettingsGroup(
      title: 'Connection',
      children: [
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
