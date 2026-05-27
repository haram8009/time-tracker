import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool enabled;
  final int sleepStartMinute; // minutes from midnight, default 23*60
  final int sleepEndMinute;   // minutes from midnight, default 7*60

  const NotificationSettings({
    this.enabled = true,
    this.sleepStartMinute = 1380,
    this.sleepEndMinute = 420,
  });

  NotificationSettings copyWith({
    bool? enabled,
    int? sleepStartMinute,
    int? sleepEndMinute,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        sleepStartMinute: sleepStartMinute ?? this.sleepStartMinute,
        sleepEndMinute: sleepEndMinute ?? this.sleepEndMinute,
      );
}

class SettingsService extends StateNotifier<NotificationSettings> {
  static const _keyEnabled = 'notif_enabled';
  static const _keySleepStart = 'notif_sleep_start';
  static const _keySleepEnd = 'notif_sleep_end';

  SettingsService() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      sleepStartMinute: prefs.getInt(_keySleepStart) ?? 1380,
      sleepEndMinute: prefs.getInt(_keySleepEnd) ?? 420,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  Future<void> setSleepStart(int minute) async {
    state = state.copyWith(sleepStartMinute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySleepStart, minute);
  }

  Future<void> setSleepEnd(int minute) async {
    state = state.copyWith(sleepEndMinute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySleepEnd, minute);
  }
}

final settingsServiceProvider =
    StateNotifierProvider<SettingsService, NotificationSettings>(
        (_) => SettingsService());
