import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../tunnel/presentation/controller/tunnel_controller.dart';
import '../../tunnel/presentation/controller/vpn_session.dart';
import '../domain/installed_app.dart';
import 'controller/split_tunnel_controller.dart';

/// Which apps skip the tunnel.
///
/// The feature exists mostly for one reason people hit immediately: banking and
/// payment apps that refuse to run when they see a VPN. Without a way to exclude
/// those, the honest choice a user faces is between their bank and their VPN,
/// and the VPN loses.
///
/// Excluded apps are named to the system when the interface is built, so their
/// traffic never enters the tun device at all. Nothing is routed around a live
/// tunnel — which is why a change here needs a reconnect, and why the banner
/// above the list says so instead of quietly dropping the connection.
class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(installedAppsProvider);
    final excluded = ref.watch(excludedAppsProvider).value ?? const <String>{};
    final isReconnecting =
        ref.watch(vpnSessionProvider).isLoading ||
        ref.watch(tunnelControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split tunnelling'),
        actions: [
          if (excluded.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(excludedAppsProvider.notifier).clear(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: AsyncView(
        value: apps,
        onRetry: () => ref.invalidate(installedAppsProvider),
        data: (list) {
          if (list.isEmpty) return const _NoApps();

          final visible = list.where((app) => app.matches(_query)).toList();

          return Column(
            children: [
              _Intro(
                excludedCount: excluded.length,
                isReconnecting: isReconnecting,
              ),
              _SearchField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const _NoMatches()
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: 24.h),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final app = visible[index];
                          return _AppRow(
                            app: app,
                            excluded: excluded.contains(app.package),
                            onChanged: (value) => ref
                                .read(excludedAppsProvider.notifier)
                                .toggle(app.package, excluded: value),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.excludedCount, required this.isReconnecting});

  final int excludedCount;

  /// True while a split-tunnel change is cycling the tunnel.
  final bool isReconnecting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            excludedCount == 0
                ? 'Every app uses the tunnel. Tick an app to keep its traffic on '
                      'your normal connection instead.'
                : '$excludedCount app${excludedCount == 1 ? '' : 's'} will bypass '
                      'the tunnel and use your normal connection.',
            style: TextStyle(
              fontSize: 12.5.sp,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          if (isReconnecting) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14.r,
                    height: 14.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Applying changes — reconnecting the tunnel…',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textHigh,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search apps',
          prefixIcon: Icon(Icons.search, size: 19.r),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.excluded,
    required this.onChanged,
  });

  final InstalledApp app;
  final bool excluded;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: excluded,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.trailing,
      // No icons: pulling a bitmap per app across the platform channel costs
      // more than a picker is worth, so the initial stands in for one.
      secondary: CircleAvatar(
        radius: 17.r,
        backgroundColor: AppColors.surface,
        child: Text(
          app.label.characters.firstOrNull?.toUpperCase() ?? '?',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textHigh,
          ),
        ),
      ),
      title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        app.isSystem ? '${app.package} · system' : app.package,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
      ),
    );
  }
}

class _NoApps extends StatelessWidget {
  const _NoApps();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.r),
        child: Text(
          'This device did not return a list of apps, so there is nothing to '
          'exclude. Split tunnelling is an Android feature; it does nothing here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No apps match that.',
        style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
      ),
    );
  }
}
