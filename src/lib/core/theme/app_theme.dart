import 'package:flutter/material.dart';

class AppTheme {
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
