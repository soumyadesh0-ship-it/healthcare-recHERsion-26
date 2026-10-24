import 'package:flutter/material.dart';

abstract final class Palette {
  static const plum = Color(0xFF45364B);
  static const orchid = Color(0xFFDD7ED9);
  static const mist = Color(0xFFF4EFF4);
  static const apricot = Color(0xFFF5B07E);
  static const blush = Color(0xFFF9E3D8);
}

ThemeData auracareTheme() {
  const scheme = ColorScheme.light(
    primary: Palette.plum,
    onPrimary: Palette.mist,
    primaryContainer: Palette.blush,
    onPrimaryContainer: Palette.plum,
    secondary: Palette.apricot,
    onSecondary: Palette.plum,
    secondaryContainer: Palette.blush,
    onSecondaryContainer: Palette.plum,
    tertiary: Palette.orchid,
    onTertiary: Palette.plum,
    tertiaryContainer: Palette.mist,
    onTertiaryContainer: Palette.plum,
    error: Palette.plum,
    onError: Palette.mist,
    errorContainer: Palette.blush,
    onErrorContainer: Palette.plum,
    surface: Palette.mist,
    onSurface: Palette.plum,
    surfaceContainerLowest: Palette.mist,
    surfaceContainerLow: Palette.mist,
    surfaceContainer: Palette.blush,
    surfaceContainerHigh: Palette.blush,
    surfaceContainerHighest: Palette.blush,
    onSurfaceVariant: Palette.plum,
    outline: Palette.plum,
    outlineVariant: Palette.plum,
    shadow: Palette.plum,
    scrim: Palette.plum,
    inverseSurface: Palette.plum,
    onInverseSurface: Palette.mist,
    inversePrimary: Palette.apricot,
    surfaceTint: Palette.mist,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.mist,
    canvasColor: Palette.mist,
    dividerColor: Palette.plum.withValues(alpha: .16),
    splashColor: Palette.plum.withValues(alpha: .08),
    highlightColor: Palette.plum.withValues(alpha: .05),
    focusColor: Palette.plum.withValues(alpha: .16),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: Palette.plum,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: Palette.plum,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Palette.plum,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Palette.plum,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Palette.plum),
      bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: Palette.plum),
      bodySmall: TextStyle(fontSize: 14, height: 1.4, color: Palette.plum),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Palette.plum,
      ),
      labelMedium: TextStyle(fontSize: 14, color: Palette.plum),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.mist,
      foregroundColor: Palette.plum,
      surfaceTintColor: Palette.mist,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.plum,
        foregroundColor: Palette.mist,
        disabledBackgroundColor: Palette.blush,
        disabledForegroundColor: Palette.plum,
        minimumSize: const Size(48, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.plum,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Palette.plum),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.blush,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Palette.plum.withValues(alpha: .3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.plum, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.mist,
      selectedColor: Palette.blush,
      labelStyle: const TextStyle(color: Palette.plum),
      side: const BorderSide(color: Palette.plum),
      padding: const EdgeInsets.all(8),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.plum,
      contentTextStyle: TextStyle(color: Palette.mist),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.plum,
      linearTrackColor: Palette.blush,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.plum : Palette.mist,
      ),
      checkColor: const WidgetStatePropertyAll(Palette.mist),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Palette.mist),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.plum : Palette.blush,
      ),
    ),
  );
}
