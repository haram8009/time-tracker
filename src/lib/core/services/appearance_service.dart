import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_block_style.dart';
import 'preferences_port.dart';

class AppearanceService extends StateNotifier<TimeBlockStyle> {
  static const _keyBlockStyle = 'appearance_block_style';

  final PreferencesPort _prefs;

  AppearanceService(this._prefs) : super(TimeBlockStyle.tintBar) {
    _load();
  }

  void _load() {
    final index = _prefs.getInt(_keyBlockStyle) ?? 0;
    state = TimeBlockStyle.values[index.clamp(0, TimeBlockStyle.values.length - 1)];
  }

  Future<void> setBlockStyle(TimeBlockStyle style) async {
    state = style;
    await _prefs.setInt(_keyBlockStyle, style.index);
  }
}

final appearanceServiceProvider =
    StateNotifierProvider<AppearanceService, TimeBlockStyle>(
        (ref) => AppearanceService(ref.read(sharedPrefsAdapterProvider)));

class ThemeModeService extends StateNotifier<ThemeMode> {
  static const _keyThemeMode = 'appearance_theme_mode';

  final PreferencesPort _prefs;

  ThemeModeService(this._prefs) : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    final index = _prefs.getInt(_keyThemeMode) ?? 0;
    state = ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setInt(_keyThemeMode, mode.index);
  }
}

final themeModeServiceProvider =
    StateNotifierProvider<ThemeModeService, ThemeMode>(
        (ref) => ThemeModeService(ref.read(sharedPrefsAdapterProvider)));
