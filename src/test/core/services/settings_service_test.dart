import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/notifications/notification_settings.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/services/settings_service.dart';

class _FakePrefs implements PreferencesPort {
  final Map<String, Object> _store = {};

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  Future<void> setBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _store[key] = value;
}

class _FakeNotificationPort implements NotificationPort {
  final List<Map<String, dynamic>> scheduledCalls = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelById(int id) async => cancelledIds.add(id);

  @override
  Future<void> scheduleAtTime({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {
    scheduledCalls.add({'id': id, 'title': title});
  }
}

void main() {
  group('SettingsService', () {
    test('기본값으로 초기화', () {
      final svc = SettingsService(_FakePrefs(), _FakeNotificationPort());
      expect(svc.state.enabled, isTrue);
      expect(svc.state.sleepStartMinute, 1380);
      expect(svc.state.sleepEndMinute, 420);
    });

    test('저장된 값 로드', () {
      final prefs = _FakePrefs()
        .._store[NotificationSettings.keyEnabled] = false
        .._store[NotificationSettings.keySleepStart] = 1320
        .._store[NotificationSettings.keySleepEnd] = 480;
      final svc = SettingsService(prefs, _FakeNotificationPort());
      expect(svc.state.enabled, isFalse);
      expect(svc.state.sleepStartMinute, 1320);
      expect(svc.state.sleepEndMinute, 480);
    });

    test('setEnabled → state 변경 + prefs 저장', () async {
      final prefs = _FakePrefs();
      final svc = SettingsService(prefs, _FakeNotificationPort());
      await svc.setEnabled(false);
      expect(svc.state.enabled, isFalse);
      expect(prefs.getBool(NotificationSettings.keyEnabled), isFalse);
    });

    test('setSleepStart → state 변경 + prefs 저장', () async {
      final prefs = _FakePrefs();
      final svc = SettingsService(prefs, _FakeNotificationPort());
      await svc.setSleepStart(1320);
      expect(svc.state.sleepStartMinute, 1320);
      expect(prefs.getInt(NotificationSettings.keySleepStart), 1320);
    });

    test('setSleepEnd → state 변경 + prefs 저장', () async {
      final prefs = _FakePrefs();
      final svc = SettingsService(prefs, _FakeNotificationPort());
      await svc.setSleepEnd(480);
      expect(svc.state.sleepEndMinute, 480);
      expect(prefs.getInt(NotificationSettings.keySleepEnd), 480);
    });

    test('setEnabled → scheduleWeeklyFallback 호출 (port.cancelById 확인)', () async {
      final port = _FakeNotificationPort();
      final svc = SettingsService(_FakePrefs(), port);
      await svc.setEnabled(true);
      expect(port.cancelledIds, isNotEmpty);
    });

    test('enabled=false → setEnabled(false) → 폴백 schedule 없음', () async {
      final port = _FakeNotificationPort();
      final svc = SettingsService(_FakePrefs(), port);
      await svc.setEnabled(false);
      expect(port.scheduledCalls, isEmpty);
    });
  });
}
