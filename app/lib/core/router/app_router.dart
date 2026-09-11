import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_routes.dart';
import '../session/session_controller.dart';
import 'app_routes.dart';
import 'splash_screen.dart';

part 'app_router.g.dart';

/// The app's router, with auth-gating in a single `redirect`.
///
/// Gating centrally — rather than each screen checking for a session — is what
/// makes the interceptor's "refresh token rejected" path work: it flips
/// [sessionProvider] to unauthenticated and every screen in the stack unwinds to
/// the login page, wherever the user happened to be.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final sessionListenable = _SessionListenable(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    // A plain notifier bridged from the session provider. go_router re-runs
    // `redirect` whenever this fires.
    refreshListenable: sessionListenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final onAuthScreen = location == AppRoutes.login || location == AppRoutes.register;

      // Still reading the keystore. Hold on the splash screen rather than guess,
      // which is what avoids a flash of the login page for a signed-in user.
      if (session.isLoading || !session.hasValue) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final signedIn = session.requireValue == SessionStatus.authenticated;

      if (!signedIn) return onAuthScreen ? null : AppRoutes.login;
      if (onAuthScreen || location == AppRoutes.splash) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterScreen()),
      // The signed-in shell and its tabs. Kept in the home module so this file
      // does not change every time a feature adds a screen.
      ...buildHomeRoutes(),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    sessionListenable.dispose();
  });
  return router;
}

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    _subscription = ref.listen(
      sessionProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
