import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Deliberately plain Material 3. The point of this build is that every field the
/// backend returns is visible and legible, not that it is styled.
///
/// Every dimension is scaled with ScreenUtil against the design size declared in
/// `AegisApp.designSize`, so the same layout holds from a small phone to a tablet.
abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D6F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: Size.fromHeight(48.h)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(44.h)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// One spacing scale, so screens do not each invent their own padding.
///
/// These are getters, not constants: ScreenUtil resolves against the live screen,
/// so a `const SizedBox` would bake in an unscaled value.
abstract final class Gap {
  static SizedBox get xs => SizedBox(height: 4.h, width: 4.w);
  static SizedBox get sm => SizedBox(height: 8.h, width: 8.w);
  static SizedBox get md => SizedBox(height: 16.h, width: 16.w);
  static SizedBox get lg => SizedBox(height: 24.h, width: 24.w);

  /// Standard screen padding.
  static EdgeInsets get page => EdgeInsets.all(16.r);
}
