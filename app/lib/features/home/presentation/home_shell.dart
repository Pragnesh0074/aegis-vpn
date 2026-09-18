import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../autoconnect/presentation/auto_connect_controller.dart';
import '../../autoconnect/presentation/wifi_notice_watcher.dart';
import '../../history/presentation/session_recorder.dart';
import '../../killswitch/presentation/kill_switch_controller.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../../tunnel/presentation/platform_connect_watcher.dart';

/// Bottom-nav shell for the signed-in app.
///
/// Backed by go_router's `StatefulShellRoute`, so each tab keeps its own
/// navigation stack and scroll position when the user switches away and back.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Four things that have to be alive for as long as there is a session, and
    // only while there is one. None of them draws anything. Mounted here because
    // this shell is the whole of the signed-in app — put them on the connect
    // screen and they would stop the moment someone opened another tab.
    //
    // The two settings are here for a reason worth stating: both live natively
    // as process state, and both are pushed down to the platform when their
    // controller first builds. Until this was watched here, that first build
    // happened when the account tab was opened — so a kill switch someone armed
    // last week was not armed again after a restart until they happened to go
    // and look at it. A protection setting that is silently absent is the one
    // failure this app has repeatedly said it will not ship.
    ref
      ..watch(killSwitchControllerProvider)
      ..watch(autoConnectProvider)
      // Turns finished tunnels into history rows.
      ..watch(sessionRecorderProvider)
      // Serves a connect the platform asked for but could not perform: a tile
      // tapped on a cold start, or auto-connect holding no config.
      ..watch(platformConnectWatcherProvider)
      // Records joined networks and catches the "you are on an untrusted
      // network" notice. Here for the same reason as the rest: the join it
      // exists to catch happens with no screen open.
      ..watch(wifiNoticeWatcherProvider);

    // The shield tints while the tunnel is up, so the state is legible from any
    // tab without having to go back to the connect screen.
    final status = ref.watch(tunnelStatusStreamProvider).value;
    final isUp = status != null && status.state.isUp;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: NavigationBar(
          height: 66.h,
          selectedIndex: navigationShell.currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          // `initialLocation: true` on a re-tap pops that tab back to its root,
          // which is the behaviour people expect from a tab bar.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: Icon(
                isUp ? Icons.shield_rounded : Icons.shield_outlined,
                color: isUp ? AppColors.accent : null,
              ),
              selectedIcon: Icon(
                Icons.shield_rounded,
                color: isUp ? AppColors.accent : null,
              ),
              label: 'Shield',
            ),
            const NavigationDestination(
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public),
              label: 'Locations',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
