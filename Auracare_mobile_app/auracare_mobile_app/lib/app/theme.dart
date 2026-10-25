import 'package:flutter/material.dart';

abstract final class Palette {
  static const purple = Color(0xFFB49AD6);
  static const white = Color(0xFFFFFFFF);
  static const lavender = Color(0xFFE7DEF1);
  static const pink = Color(0xFFEFA8C5);
  static const blush = Color(0xFFF9DFEA);
  static const yellow = Color(0xFFF6D794);
  static const coral = Color(0xFFE99A8B);
  static const turquoise = Color(0xFF89CECA);
  static const blue = Color(0xFFA6BCE1);
  static const periwinkle = blue;
  static const ink = Color(0xFF34283D);
  static const flowInk = Color(0xFF24192C);
  static const secondary = Color(0xFF746A7B);
  static const input = Color(0xFFFAF8FB);
  // Dark lavender for small action text and focus outlines on white.
  static const action = Color(0xFF705488);
  static const lightFlow = Color(0xFFF8D9E3);
  static const moderateFlow = Color(0xFFEFA0B9);
  static const heavyFlow = Color(0xFFD66F91);
  static const happyMood = Color(0xFFE8BC71);
  static const tiredMood = Color(0xFFB8A9CF);
  static const follicular = Color(0xFFD8EDE5);
  static const fertile = Color(0xFFB8DED2);
  static const ovulation = Color(0xFF89BDB1);
  static const approaching = [
    Color(0xFFFCF0F5),
    Color(0xFFF9E7EE),
    Color(0xFFF6DEE7),
  ];
  static const plum = ink;
  static const orchid = lavender;
  static const mist = white;
  static const apricot = yellow;
  static const tiles = [blush, periwinkle, lavender, yellow, turquoise];
}

ThemeData auracareTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: Palette.action,
      onPrimary: Palette.white,
      primaryContainer: Palette.lavender,
      onPrimaryContainer: Palette.ink,
      secondary: Palette.turquoise,
      onSecondary: Palette.ink,
      secondaryContainer: Palette.blush,
      onSecondaryContainer: Palette.ink,
      surface: Palette.white,
      onSurface: Palette.ink,
      onSurfaceVariant: Palette.secondary,
      surfaceContainerHighest: Palette.input,
      outline: Palette.secondary,
      outlineVariant: Palette.input,
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: Palette.white,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide.none,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: Palette.ink,
            letterSpacing: -1.2,
          ),
          headlineMedium: const TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: Palette.ink,
            letterSpacing: -.8,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: Palette.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Palette.ink,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Palette.secondary,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.white,
      foregroundColor: Palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Palette.ink,
        letterSpacing: -.7,
      ),
    ),
    dividerColor: Palette.input,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.purple,
        foregroundColor: Palette.ink,
        elevation: 0,
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Palette.periwinkle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.input,
      contentPadding: const EdgeInsets.all(18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Palette.action, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.input,
      selectedColor: Palette.lavender,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(color: Palette.ink),
      padding: const EdgeInsets.all(8),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.ink,
      contentTextStyle: TextStyle(color: Palette.white),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.purple,
      linearTrackColor: Palette.input,
    ),
  );
}
