import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'generated/l10n.dart';

class AegisApp extends ConsumerWidget {
  const AegisApp({super.key});

  /// The frame every `.w` / `.h` / `.sp` in the app is relative to. 375x812 is a
  /// notched-phone logical viewport — the size the screens were laid out at.
  static const designSize = Size(375, 812);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: designSize,
      // Text stays legible on a small screen instead of shrinking with the
      // viewport; without this, `.sp` on a compact phone is unreadable.
      minTextAdapt: true,
      splitScreenMode: true,
      // The router is built once and reused: rebuilding it per frame would reset
      // navigation state.
      builder: (context, child) => MaterialApp.router(
        title: 'Aegis VPN',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        // Dark only, and pinned rather than following the system: the connect
        // screen is built out of glows over a near-black ground, so a light
        // variant would be a second design rather than a recolour.
        theme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: ref.watch(appRouterProvider),
      ),
    );
  }
}
