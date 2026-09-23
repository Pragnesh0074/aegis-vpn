import 'package:aegis_vpn/app.dart';
import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:aegis_vpn/generated/l10n.dart';
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

/// Answers the tunnel MethodChannel with a platform that has no tunnel.
///
/// Without this, any `invokeMethod` in a widget test never completes: with no
/// mock handler the call is forwarded to a platform that is not there, so the
/// future hangs and `pumpAndSettle` times out behind a spinner rather than
/// failing on anything informative. The EventChannel is deliberately left
/// unmocked — subscribing does not await a reply, and a stream that never emits
/// is exactly what a test device looks like.
void stubTunnelChannel() {
  const channel = MethodChannel('vpn.aegis/tunnel');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    return switch (call.method) {
      'status' => <String, Object?>{'state': 'disconnected', 'killSwitch': false},
      // Accepted but inert: nothing here brings a tunnel up.
      'connect' || 'disconnect' || 'setKillSwitch' => null,
      'openVpnSettings' => true,
      _ => null,
    };
  });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
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

  stubTunnelChannel();

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
        builder: (context, _) => MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: child,
        ),
      ),
    ),
  );
  await tester.pump();
}
