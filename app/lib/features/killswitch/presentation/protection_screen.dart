import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/detail_row.dart';
import '../../autoconnect/presentation/widgets/auto_connect_card.dart';
import '../../tunnel/data/tunnel_channel.dart';
import 'kill_switch_controller.dart';

/// Everything that decides when the tunnel is up without the user tapping the
/// button — and an honest account of what each part cannot do.
///
/// Three cards, in the order the gaps appear. Auto-connect brings a tunnel up
/// that was never running; the kill switch rebuilds one that dropped; Android's
/// own setting is the only thing that blocks traffic when neither worked.
///
/// The explanations are not padding. "Kill switch" in most VPN apps means
/// traffic is blocked whenever the tunnel is down, and on Android an app simply
/// cannot do that — only the system can, through a setting no app may enable for
/// itself. Shipping a toggle called "kill switch" without saying so would let
/// someone believe they are covered when the app is closed, which is precisely
/// when they are not. Auto-connect has the same shape of limit and gets the same
/// treatment.
class ProtectionScreen extends ConsumerWidget {
  const ProtectionScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref
          .read(killSwitchControllerProvider.notifier)
          .setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  Future<void> _openSystemSettings(BuildContext context, WidgetRef ref) async {
    final opened =
        await ref.read(killSwitchControllerProvider.notifier).openSystemVpnSettings();
    if (!context.mounted || opened) return;
    showMessage(
      context,
      'This device has no VPN settings screen to open. Look for VPN under '
      'network settings.',
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(killSwitchControllerProvider);
    // The platform's own answer, which is what actually rebuilds a tunnel.
    final armed = ref.watch(tunnelStatusStreamProvider).value?.killSwitch ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Protection')),
      body: AsyncView(
        value: setting,
        onRetry: () => ref.invalidate(killSwitchControllerProvider),
        data: (enabled) => ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
          children: [
            const AutoConnectCard(),
            Gap.md,
            _ReconnectCard(
              enabled: enabled,
              armed: armed,
              onChanged: (value) => _toggle(context, ref, value),
            ),
            Gap.md,
            _SystemLockdownCard(onOpen: () => _openSystemSettings(context, ref)),
            Gap.md,
            const _QuickTileCard(),
            Gap.md,
            const _WhatIsProtected(),
          ],
        ),
      ),
    );
  }
}

/// Offers the pull-down tile.
///
/// The tile exists whether or not anyone ever taps this — it is declared in the
/// manifest — but a tile nobody has added is a tile nobody knows about, and
/// editing the shade by hand is not something people do. Android draws its own
/// prompt; an app is not allowed to add one for itself.
class _QuickTileCard extends ConsumerWidget {
  const _QuickTileCard();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await ref.read(tunnelChannelProvider).requestAddTile();
    if (!context.mounted) return;

    showMessage(
      context,
      added
          ? 'Added. Pull down and tap Aegis to connect.'
          : 'Not added. On Android 12 and earlier, pull down the shade, edit the '
              'tiles and drag Aegis in.',
      isError: !added,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect from the pull-down shade',
            style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'A Quick Settings tile, next to Wi-Fi and Bluetooth. Two swipes '
            'instead of opening the app. Disconnecting always works from there; '
            'connecting opens Aegis if it has to set a peer up first.',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: () => _add(context, ref),
            icon: Icon(Icons.add_to_home_screen, size: 17.r),
            label: const Text('Add the tile'),
          ),
        ],
      ),
    );
  }
}

class _ReconnectCard extends StatelessWidget {
  const _ReconnectCard({
    required this.enabled,
    required this.armed,
    required this.onChanged,
  });

  final bool enabled;

  /// What the platform reports. Disagreement with [enabled] is worth showing.
  final bool armed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rebuild the tunnel if it drops',
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'If the connection is lost without you asking — a dropped network, '
            'the system reclaiming the VPN — Aegis brings it straight back, up '
            'to five times with a growing delay.',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          if (enabled && !armed) ...[
            SizedBox(height: 12.h),
            const _Warning(
              text: 'Saved, but not armed on this device yet. It takes effect '
                  'once the VPN service has run at least once.',
            ),
          ],
        ],
      ),
    );
  }
}

/// The part that actually blocks traffic, which this app cannot switch on.
class _SystemLockdownCard extends StatelessWidget {
  const _SystemLockdownCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 18.r, color: AppColors.warn),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Block all traffic without a VPN',
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Only Android can stop traffic while no tunnel is up, and it does not '
            'let an app turn that on for itself. In VPN settings, set Aegis as '
            'Always-on VPN and enable "Block connections without VPN".',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          SizedBox(height: 14.h),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Open Android VPN settings'),
          ),
          SizedBox(height: 10.h),
          const _Warning(
            text: 'Turn on Always-on VPN together with blocking. Blocking alone, '
                'with nothing bringing the tunnel up, leaves the phone with no '
                'network at all.',
          ),
        ],
      ),
    );
  }
}

class _WhatIsProtected extends StatelessWidget {
  const _WhatIsProtected();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('While connected', 'All traffic goes through the tunnel. Nothing routes around it, '
          'and if the server stops answering, packets are dropped rather than sent in the clear.'),
      ('While connecting', 'Traffic is not protected until the tunnel is up.'),
      ('While disconnected', 'Traffic uses your normal connection. Nothing but Android\'s '
          'own blocking can change that.'),
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT IS PROTECTED',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 12.h),
          for (final (title, body) in rows) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              body,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted, height: 1.4),
            ),
            if (title != rows.last.$1) SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.warn.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.warn.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15.r, color: AppColors.warn),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.textHigh, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
