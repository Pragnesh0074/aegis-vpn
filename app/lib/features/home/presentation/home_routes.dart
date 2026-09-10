import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../devices/presentation/devices_screen.dart';
import '../../nodes/presentation/nodes_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'home_shell.dart';

/// Routes behind the session gate: one branch per bottom-nav tab.
///
/// Assembled here rather than in `app_router.dart` so adding a feature tab does
/// not touch the router's redirect logic.
List<RouteBase> buildHomeRoutes() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.devices, builder: (_, _) => const DevicesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.servers, builder: (_, _) => const NodesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ];
}
