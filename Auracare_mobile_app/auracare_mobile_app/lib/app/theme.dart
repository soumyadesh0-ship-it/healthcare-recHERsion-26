import 'package:flutter/material.dart';

abstract final class Palette {
  static const purple = Color(0xFF7838C8);
  static const white = Color(0xFFFFFFFF);
  static const lavender = Color(0xFFC8A8E8);
  static const pink = Color(0xFFF28AB8);
  static const blush = Color(0xFFF8CBDF);
  static const yellow = Color(0xFFFFAE20);
  static const coral = Color(0xFFF57858);
  static const turquoise = Color(0xFF27BDB5);
  static const blue = Color(0xFF7597D3);
  static const periwinkle = Color(0xFFB7C8E6);
  static const ink = Color(0xFF111111);
  static const secondary = Color(0xFF666666);
  static const input = Color(0xFFF5F5F7);
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
      primary: Palette.purple,
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
        foregroundColor: Palette.white,
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
        borderSide: const BorderSide(color: Palette.purple, width: 2),
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
