import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/detail_row.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../../tunnel/presentation/tunnel_controller.dart';
import '../domain/auto_connect_settings.dart';
import 'auto_connect_controller.dart';

/// The networks auto-connect leaves alone.
///
/// Auto-connect brings the tunnel up on joining any Wi-Fi that is *not* on this
/// list, so an empty list means it connects on every network — including the
/// user's own home one. That is a reasonable default for a privacy tool and a
/// poor one for a phone that lives on one network, which is why the list has to
/// be reachable rather than implied.
///
/// Naming a network needs a location permission, because Android treats an SSID
/// as location data. Without it Android will not say which network the device is
/// on, every network reads as untrusted, and the list cannot be added to at all —
/// so the permission ask leads, and says why a VPN is asking.
class TrustedNetworksScreen extends ConsumerWidget {
  const TrustedNetworksScreen({super.key});

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
    // Trusting the network you are standing on means the tunnel auto-connect
    // raised for it should come down — leaving it up would honour half the
    // request. `disconnect` marks the drop as user-requested, so the kill switch
    // does not rebuild it.
    await ref.read(tunnelControllerProvider.notifier).disconnect();
    if (!context.mounted) return;

    ref.invalidate(currentWifiProvider);
    showMessage(context, '$ssid is trusted. Aegis disconnected and will leave it alone.');
  }

  /// Trusts a network from the "recently joined" list.
  ///
  /// Only drops the tunnel when it is the network the device is actually on.
  /// Trusting the office from the sofa should not disconnect you from the café
  /// you are sitting in.
  Future<void> _trustSeen(WidgetRef ref, String ssid, {required bool isCurrent}) async {
    await ref.read(autoConnectProvider.notifier).trust(ssid);
    if (isCurrent) {
      await ref.read(tunnelControllerProvider.notifier).disconnect();
    }
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
    final settings = ref.watch(autoConnectProvider).value ?? AutoConnectSettings.off;
    final hasPermission =
        ref.watch(tunnelStatusStreamProvider).value?.hasWifiPermission ?? false;
    final current = ref.watch(currentWifiProvider).value?.ssid;
    final alreadyTrusted = current != null && settings.trusts(current);

    return Scaffold(
      appBar: AppBar(title: const Text('Trusted networks')),
      body: ListView(
        padding: Gap.page,
        children: [
          Text(
            settings.trusted.isEmpty
                ? 'Aegis connects automatically on every Wi-Fi network. Add the '
                    'ones you trust — your home or office — and it will leave '
                    'those alone.'
                : 'Aegis connects automatically on any Wi-Fi except these.',
            style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted, height: 1.4),
          ),
          Gap.md,
          if (!hasPermission)
            _PermissionCard(onGrant: () => _grant(context, ref))
          else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                // Nothing to add with no Wi-Fi to name, and nothing to do when it
                // is already on the list.
                onPressed:
                    current == null || alreadyTrusted ? null : () => _trust(context, ref),
                icon: Icon(Icons.add, size: 17.r),
                label: Text(
                  switch (current) {
                    null => 'Not on Wi-Fi',
                    final ssid when alreadyTrusted => '$ssid is already trusted',
                    final ssid => 'Trust $ssid',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Gap.md,
            if (settings.trusted.isEmpty)
              Text(
                'Nothing trusted yet.',
                style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
              )
            else
              for (final ssid in settings.trusted)
                _TrustedRow(
                  ssid: ssid,
                  onForget: () => ref.read(autoConnectProvider.notifier).forget(ssid),
                ),

            // Networks this device has actually joined. The point of the list is
            // that you can trust the office from your sofa — without it, the only
            // way to add a network is to be standing on it, which means nobody
            // ever sets this up until the moment it is already too late.
            if (settings.untrustedSeen.isNotEmpty) ...[
              Gap.lg,
              Text(
                'RECENTLY JOINED',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Networks this phone has connected to. Aegis turns on for all of '
                'them until you say otherwise.',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted, height: 1.35),
              ),
              SizedBox(height: 10.h),
              for (final ssid in settings.untrustedSeen)
                _SeenRow(
                  ssid: ssid,
                  isCurrent: ssid == current,
                  onTrust: () => _trustSeen(ref, ssid, isCurrent: ssid == current),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A network the device has joined but not trusted, with the one action that
/// matters. No "forget": it is a record of where this phone has been, and
/// removing an entry would only mean it reappears the next time you go there.
class _SeenRow extends StatelessWidget {
  const _SeenRow({
    required this.ssid,
    required this.isCurrent,
    required this.onTrust,
  });

  final String ssid;
  final bool isCurrent;
  final VoidCallback onTrust;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.only(left: 14.w, right: 6.w, top: 4.h, bottom: 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, size: 17.r, color: AppColors.textMuted),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5.sp, color: AppColors.textHigh),
                ),
                if (isCurrent)
                  Text(
                    "you're on this now",
                    style: TextStyle(fontSize: 11.sp, color: AppColors.accent),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onTrust, child: const Text('Trust')),
        ],
      ),
    );
  }
}

class _TrustedRow extends StatelessWidget {
  const _TrustedRow({required this.ssid, required this.onForget});

  final String ssid;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, size: 17.r, color: AppColors.textMuted),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              ssid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5.sp, color: AppColors.textHigh),
            ),
          ),
          IconButton(
            tooltip: 'Stop trusting $ssid',
            visualDensity: VisualDensity.compact,
            onPressed: onForget,
            icon: Icon(Icons.close, size: 17.r, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Asks for the location permission, and says why a VPN is asking for it.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
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
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted, height: 1.4),
          ),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: onGrant,
            child: const Text('Allow network names'),
          ),
        ],
      ),
    );
  }
}
