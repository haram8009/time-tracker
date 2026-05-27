import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifications/notification_port.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/notification_settings.dart';
import 'preferences_port.dart';

export '../notifications/notification_settings.dart';

class SettingsService extends StateNotifier<NotificationSettings> {
  static const _keyEnabled = NotificationSettings.keyEnabled;
  static const _keySleepStart = NotificationSettings.keySleepStart;
  static const _keySleepEnd = NotificationSettings.keySleepEnd;

  final PreferencesPort _prefs;
  final NotificationPort _port;

  SettingsService(this._prefs, this._port) : super(const NotificationSettings()) {
    _load();
  }

  void _load() {
    state = NotificationSettings(
      enabled: _prefs.getBool(_keyEnabled) ?? true,
      sleepStartMinute: _prefs.getInt(_keySleepStart) ?? 1380,
      sleepEndMinute: _prefs.getInt(_keySleepEnd) ?? 420,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _prefs.setBool(_keyEnabled, value);
    await scheduleWeeklyFallbackNotifications(state, _port);
  }

  Future<void> setSleepStart(int minute) async {
    state = state.copyWith(sleepStartMinute: minute);
    await _prefs.setInt(_keySleepStart, minute);
    await scheduleWeeklyFallbackNotifications(state, _port);
  }

  Future<void> setSleepEnd(int minute) async {
    state = state.copyWith(sleepEndMinute: minute);
    await _prefs.setInt(_keySleepEnd, minute);
    await scheduleWeeklyFallbackNotifications(state, _port);
  }
}

final settingsServiceProvider =
    StateNotifierProvider<SettingsService, NotificationSettings>(
        (ref) => SettingsService(
              ref.read(sharedPrefsAdapterProvider),
              ref.read(notificationPortProvider),
            ));
