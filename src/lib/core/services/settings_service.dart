import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/sync_metadata.dart';
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
      enabled: _prefs.getBool(_keyEnabled) ?? NotificationSettings.defaultEnabled,
      sleepStartMinute:
          _prefs.getInt(_keySleepStart) ?? NotificationSettings.defaultSleepStart,
      sleepEndMinute:
          _prefs.getInt(_keySleepEnd) ?? NotificationSettings.defaultSleepEnd,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _prefs.setBool(_keyEnabled, value);
    await _stampDirty();
    await scheduleWeeklyFallbackNotifications(state, _port);
  }

  Future<void> setSleepStart(int minute) async {
    state = state.copyWith(sleepStartMinute: minute);
    await _prefs.setInt(_keySleepStart, minute);
    await _stampDirty();
    await scheduleWeeklyFallbackNotifications(state, _port);
  }

  Future<void> setSleepEnd(int minute) async {
    state = state.copyWith(sleepEndMinute: minute);
    await _prefs.setInt(_keySleepEnd, minute);
    await _stampDirty();
    await scheduleWeeklyFallbackNotifications(state, _port);
  }

  /// Marks settings as locally edited for LWW cloud sync (#94).
  Future<void> _stampDirty() async {
    await _prefs.setInt(SettingsSyncKeys.updatedAtMillis,
        DateTime.now().toUtc().millisecondsSinceEpoch);
    await _prefs.setBool(SettingsSyncKeys.dirty, true);
  }

  /// Re-reads prefs into state and reschedules after an external prefs write
  /// (e.g. cloud settings pull).
  Future<void> reload() async {
    _load();
    await scheduleWeeklyFallbackNotifications(state, _port);
  }
}

final settingsServiceProvider =
    StateNotifierProvider<SettingsService, NotificationSettings>(
        (ref) => SettingsService(
              ref.read(sharedPrefsAdapterProvider),
              ref.read(notificationPortProvider),
            ));
