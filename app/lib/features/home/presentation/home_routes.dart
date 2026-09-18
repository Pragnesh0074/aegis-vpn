import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../autoconnect/presentation/trusted_networks_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../nodes/presentation/locations_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../splittunnel/presentation/split_tunnel_screen.dart';
import 'connect_screen.dart';
import 'home_shell.dart';

/// Routes behind the session gate: one branch per bottom-nav tab.
///
/// Assembled here rather than in `app_router.dart` so adding a feature tab does
/// not touch the router's redirect logic.
///
/// `DevicesScreen` is deliberately not registered. An account holds one peer, so
/// there is nothing for a list to do; the screen is kept for when that stops
/// being true rather than rewritten from scratch then.
List<RouteBase> buildHomeRoutes() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.home, builder: (_, _) => const ConnectScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.locations, builder: (_, _) => const LocationsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.account,
              builder: (_, _) => const ProfileScreen(),
              // Nested so it keeps the tab bar and the account tab's back stack,
              // which is what makes revoking a device feel like a detour rather
              // than leaving the app.
              routes: [
                GoRoute(
                  path: AppRoutes.trustedNetworksSegment,
                  builder: (_, _) => const TrustedNetworksScreen(),
                ),
                GoRoute(
                  path: AppRoutes.splitTunnelSegment,
                  builder: (_, _) => const SplitTunnelScreen(),
                ),
                GoRoute(
                  path: AppRoutes.historySegment,
                  builder: (_, _) => const HistoryScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}
