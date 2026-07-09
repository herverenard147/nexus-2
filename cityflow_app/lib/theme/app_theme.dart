import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1E3A8A);
  static const primaryDeep = Color(0xFF00236F);
  static const onPrimary = Color(0xFFFFFFFF);

  static const fluide = Color(0xFF10B981);
  static const dense = Color(0xFFF59E0B);
  static const bloque = Color(0xFFEF4444);
  static const inondation = Color(0xFF3B82F6);

  static const background = Color(0xFFFAF8FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFEEEDF4);
  static const surfaceContainerLow = Color(0xFFF4F3FA);

  static const onSurface = Color(0xFF1A1B21);
  static const onSurfaceVariant = Color(0xFF444651);
  static const outline = Color(0xFF757682);
  static const outlineVariant = Color(0xFFC5C5D3);

  static const error = Color(0xFFBA1A1A);

  static Color trafficColor(int niveau) =>
      [fluide, dense, bloque][niveau.clamp(0, 2)];
}

abstract final class AppSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const containerMargin = 16.0;
  static const gutter = 12.0;
}

abstract final class AppRadius {
  static const chip = Radius.circular(8);
  static const card = Radius.circular(12);
  static const sheet = Radius.circular(24);

  static const chipBorder = BorderRadius.all(chip);
  static const cardBorder = BorderRadius.all(card);
  static const sheetBorder = BorderRadius.vertical(top: sheet);
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const overlay = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: Color(0xFFDCE1FF),
    onPrimaryContainer: AppColors.primaryDeep,
    secondary: AppColors.fluide,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: Color(0xFF6CF8BB),
    onSecondaryContainer: Color(0xFF006C49),
    tertiary: AppColors.dense,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: Color(0xFFFFDDB8),
    onTertiaryContainer: Color(0xFF3E2400),
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: Color(0xFFE9E7EF),
    surfaceContainerHighest: Color(0xFFE3E1E9),
  );

  final interTextTheme = GoogleFonts.interTextTheme(const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.64, height: 1.25),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.24, height: 1.33),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.56),
    bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.14, height: 1.43),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.24, height: 1.33),
  ));

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: interTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      border: OutlineInputBorder(
        borderRadius: AppRadius.cardBorder,
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.cardBorder,
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.cardBorder,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.cardBorder,
        borderSide: const BorderSide(color: AppColors.bloque),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.cardBorder,
        borderSide: const BorderSide(color: AppColors.bloque, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipBorder),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? AppColors.primary : AppColors.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active ? AppColors.primary : AppColors.onSurfaceVariant,
          size: 24,
        );
      }),
      elevation: 8,
      shadowColor: const Color(0x14000000),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
    ),
  );
}
