import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
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
  );
}
