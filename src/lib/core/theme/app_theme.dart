import 'package:flutter/material.dart';

class AppTheme {
  static const ambientGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1F3D),
      Color(0xFF1A2A3A),
      Color(0xFF1C2E1C),
    ],
  );

  static const ambientGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEDE7F6),
      Color(0xFFE0F2F1),
      Color(0xFFFFF3E0),
    ],
  );

  // Glass blur sigmas
  static const double glassBlockBlurSigma = 16.0;
  static const double glassCardBlurSigma = 24.0;

  // Glass overlay / border alphas
  static const double glassBorderAlpha = 0.32;
  static const double glassCardOverlayHigh = 0.22;
  static const double glassCardOverlayLow = 0.10;

  // Block-specific glass tint alphas
  static const double glassBlockShimmerAlpha = 0.18;
  static const double glassBlockTintHigh = 0.32;
  static const double glassBlockTintLow = 0.28;

  // Chart section alpha
  static const double glassSectionAlpha = 0.75;

  // saturate(180%) CSS filter equivalent — 4×5 row-major color matrix
  static const glassColorMatrix = ColorFilter.matrix(<double>[
    1.6296, -0.5720, -0.0576, 0, 0,
    -0.1704,  1.2280, -0.0576, 0, 0,
    -0.1704, -0.5720,  1.7424, 0, 0,
    0,        0,        0,      1, 0,
  ]);

  static const _textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: Color(0xFF8E8E93),
    ),
  );

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    dividerColor: const Color(0xFFF0F0F0),
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      surface: Color(0xFFFFFFFF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFF0F0F0)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.white : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.black
              : const Color(0xFFE5E5EA)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    textTheme: _textTheme,
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1C1C1E),
    dividerColor: const Color(0xFF2C2C2E),
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      surface: Color(0xFF1C1C1E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF3A3A3C)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? Colors.black : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF3A3A3C)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    textTheme: _textTheme,
  );
}
