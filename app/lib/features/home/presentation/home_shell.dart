import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../history/presentation/controller/session_recorder.dart';
import '../../profile/presentation/controller/profile_providers.dart';
import '../../killswitch/presentation/controller/kill_switch_controller.dart';
import '../../tunnel/data/tunnel_channel.dart';
import '../../tunnel/presentation/controller/platform_connect_watcher.dart';

/// Bottom-nav shell for the signed-in app.
///
/// Backed by go_router's `StatefulShellRoute`, so each tab keeps its own
/// navigation stack and scroll position when the user switches away and back.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  /// Index of the Account branch in `buildHomeRoutes`. Tied to the order of the
  /// destinations below and to the branch order there; the two must agree.
  static const _accountTab = 2;

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
      // Turns finished tunnels into history rows.
      ..watch(sessionRecorderProvider)
      // Serves a connect the platform asked for but could not perform: a tile
      // tapped on a cold start, or auto-connect holding no config.
      ..watch(platformConnectWatcherProvider);

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
          onDestinationSelected: (index) {
            // The account page is the one whose data goes stale without anything
            // happening in the app: entitlement expires against the clock, and a
            // subscription can be bought or lapse elsewhere. The shell keeps each
            // tab alive in an IndexedStack, so its widgets are never rebuilt from
            // scratch and nothing re-reads the profile — before this, it was
            // fetched once per app launch.
            //
            // `invalidate` rather than a fresh read, so the previous profile
            // stays on screen while the new one is in flight. `AsyncView` passes
            // `skipLoadingOnRefresh`, which is what stops this flashing a spinner
            // over content on every tab tap — /users/me takes over a second.
            if (index == _accountTab) ref.invalidate(userProfileProvider);

            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
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
