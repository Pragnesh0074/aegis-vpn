import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: ref.watch(appRouterProvider),
      ),
    );
  }
}
