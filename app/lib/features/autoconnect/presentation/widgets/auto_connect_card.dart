import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/detail_row.dart';
import '../../../tunnel/data/tunnel_channel.dart';
import '../../domain/auto_connect_settings.dart';
import '../auto_connect_controller.dart';

/// Connect on joining a Wi-Fi network the user has not marked trusted.
///
/// Sits next to the kill switch because it answers the other half of the same
/// question. The kill switch covers a tunnel that drops; this covers one that
/// was never up — walking into a café with the app in the background.
///
/// Two limits are stated on the card rather than buried, because both change
/// what the feature is worth:
///
/// It works while Aegis is running. Android does not let an app start a VPN from
/// a cold start, and nothing here wakes the app from one, so a phone that has
/// been rebooted or had Aegis swiped away will not connect on its own. The
/// always-on VPN setting one card down is the only thing that covers that.
///
/// And naming a network needs a location permission, because Android treats an
/// SSID as location data. Without it every Wi-Fi counts as untrusted — the
/// feature still works, it just cannot tell home from anywhere else.
class AutoConnectCard extends ConsumerWidget {
  const AutoConnectCard({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool enabled) async {
    try {
      await ref.read(autoConnectProvider.notifier).setEnabled(enabled: enabled);
    } catch (error) {
      if (context.mounted) showMessage(context, describeError(error), isError: true);
    }
  }

  Future<void> _trust(BuildContext context, WidgetRef ref) async {
    final ssid = await ref.read(autoConnectProvider.notifier).trustCurrentNetwork();
    if (!context.mounted) return;

    if (ssid == null) {
      showMessage(
        context,
        'Android would not name this network. Connect to Wi-Fi and allow the '
        'location permission, then try again.',
        isError: true,
      );
      return;
    }
    ref.invalidate(currentWifiProvider);
    showMessage(context, '$ssid is trusted. Aegis will not connect on it.');
  }

  Future<void> _grant(BuildContext context, WidgetRef ref) async {
    final granted = await ref.read(autoConnectProvider.notifier).requestPermission();
    if (!context.mounted) return;
    ref.invalidate(currentWifiProvider);
    if (!granted) {
      showMessage(
        context,
        'Without it, every Wi-Fi network counts as untrusted.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(autoConnectProvider);
    // The platform's own answer, which is what is actually watching.
    final status = ref.watch(tunnelStatusStreamProvider).value;
    final armed = status?.autoConnect ?? false;
    final hasPermission = status?.hasWifiPermission ?? false;

    final settings = setting.value ?? AutoConnectSettings.off;

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
                  'Connect on untrusted Wi-Fi',
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHigh,
                  ),
                ),
              ),
              Switch(
                value: settings.enabled,
                onChanged: setting.isLoading
                    ? null
                    : (value) => _toggle(context, ref, value),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Joining a Wi-Fi network you have not trusted brings the tunnel up on '
            'its own. It works while Aegis is running — Android will not let an '
            'app start a VPN after a reboot or a swipe-away.',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          if (settings.enabled && !armed) ...[
            SizedBox(height: 10.h),
            Text(
              'Saved, but the platform is not watching yet. Reopen the app if this '
              'does not clear.',
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.warn, height: 1.35),
            ),
          ],
          if (settings.enabled) ...[
            SizedBox(height: 14.h),
            if (!hasPermission)
              _PermissionRow(onGrant: () => _grant(context, ref))
            else
              _TrustedNetworks(
                settings: settings,
                onTrust: () => _trust(context, ref),
                onForget: (ssid) =>
                    ref.read(autoConnectProvider.notifier).forget(ssid),
              ),
          ],
        ],
      ),
    );
  }
}

/// Asks for the location permission, and says why a VPN is asking for it.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Android will not tell an app which Wi-Fi network it is on without '
            'location permission — it treats a network name as location data. '
            'Until you allow it, every network counts as untrusted and Aegis '
            'connects on all of them.',
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted, height: 1.4),
          ),
          SizedBox(height: 10.h),
          OutlinedButton(
            onPressed: onGrant,
            child: const Text('Allow network names'),
          ),
        ],
      ),
    );
  }
}

class _TrustedNetworks extends ConsumerWidget {
  const _TrustedNetworks({
    required this.settings,
    required this.onTrust,
    required this.onForget,
  });

  final AutoConnectSettings settings;
  final VoidCallback onTrust;
  final ValueChanged<String> onForget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentWifiProvider).value?.ssid;
    final alreadyTrusted = current != null && settings.trusts(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRUSTED NETWORKS',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 8.h),
        if (settings.trusted.isEmpty)
          Text(
            'None yet, so Aegis connects on every network.',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          )
        else
          for (final ssid in settings.trusted)
            Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Row(
                children: [
                  Icon(Icons.wifi, size: 15.r, color: AppColors.textMuted),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      ssid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5.sp, color: AppColors.textHigh),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stop trusting $ssid',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onForget(ssid),
                    icon: Icon(Icons.close, size: 16.r, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
        SizedBox(height: 8.h),
        OutlinedButton.icon(
          // Nothing to add when there is no Wi-Fi to name, and nothing to do
          // when it is already on the list.
          onPressed: current == null || alreadyTrusted ? null : onTrust,
          icon: Icon(Icons.add, size: 17.r),
          label: Text(
            switch (current) {
              null => 'Not on Wi-Fi',
              final ssid when alreadyTrusted => '$ssid is trusted',
              final ssid => 'Trust $ssid',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
