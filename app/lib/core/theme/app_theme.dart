import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The app's palette, hand-picked rather than seeded.
///
/// `ColorScheme.fromSeed` was fine while the point was legibility, but a VPN
/// client lives or dies on one signal — am I protected right now — and that
/// needs colours chosen for contrast against a near-black ground, not derived
/// from a hue wheel. The three state colours are the whole vocabulary: mint
/// means the peer is answering, amber means the interface is up but nothing is
/// coming back, red means it failed. Nothing else in the app uses them.
abstract final class AppColors {
  /// The page ground. Not pure black — a slight blue lift stops the OLED
  /// "hole" effect where a black panel reads as a gap rather than a surface.
  static const bg = Color(0xFF060911);
  static const surface = Color(0xFF0E1421);
  static const surfaceHigh = Color(0xFF171F31);
  static const outline = Color(0xFF1F2A3D);

  /// Protected. Also the brand colour.
  static const accent = Color(0xFF22E4B4);
  static const accentDeep = Color(0xFF0E9C7C);

  /// Interface up, peer silent. Deliberately not green.
  static const warn = Color(0xFFFFB443);
  static const danger = Color(0xFFFF5470);

  static const textHigh = Color(0xFFE9EEF7);
  static const textMuted = Color(0xFF8B98AF);

  /// The ground behind the connect orb, so its glow has something to sit in.
  static const aurora = Color(0xFF0A2A3A);
}

/// Dark only, on purpose.
///
/// There is no light theme: the connect screen is built out of glows and
/// gradients over a near-black ground, and every one of those reads as grey
/// mud on white. A light variant would be a second design, not a recolour.
abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF00281F),
      primaryContainer: AppColors.accentDeep,
      onPrimaryContainer: Color(0xFFD7FFF4),
      secondary: AppColors.accent,
      onSecondary: Color(0xFF00281F),
      tertiary: AppColors.warn,
      onTertiary: Color(0xFF2B1800),
      error: AppColors.danger,
      onError: Color(0xFF3A0010),
      errorContainer: Color(0xFF4A1220),
      onErrorContainer: Color(0xFFFFD9E0),
      surface: AppColors.bg,
      onSurface: AppColors.textHigh,
      surfaceContainer: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceHigh,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 19.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.textHigh,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(52.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(48.h),
          side: const BorderSide(color: AppColors.outline),
          foregroundColor: AppColors.textHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22.r,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.textHigh, fontSize: 13.sp),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.outline,
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
  static SizedBox get xl => SizedBox(height: 36.h, width: 36.w);

  /// Standard screen padding.
  static EdgeInsets get page => EdgeInsets.all(16.r);
}
