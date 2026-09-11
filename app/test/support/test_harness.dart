import 'package:aegis_vpn/app.dart';
import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 keeps `Override` out of the main export; it lives in misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegis_vpn/core/theme/app_theme.dart';

/// Stands in for the platform keystore, which has no implementation in a test VM.
class InMemorySecureStore implements SecureStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Pumps [child] inside the same `ScreenUtilInit` the real app uses.
///
/// Without it every `.w` / `.h` / `.sp` in the widget tree throws, so this is
/// what makes a widget test a real check that a screen renders under ScreenUtil.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(390, 844),
}) async {
  // The test *view*, not `setSurfaceSize`. ScreenUtil sizes itself from the view's
  // physical size, so setting only the surface leaves it scaling against the
  // default 800x600 test window while the tree renders at `surfaceSize` — every
  // `.w` then disagrees with the space actually available.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = surfaceSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: AegisApp.designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) => MaterialApp(theme: AppTheme.dark(), home: child),
      ),
    ),
  );
  await tester.pump();
}
