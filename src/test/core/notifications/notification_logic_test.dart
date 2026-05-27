import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/notifications/notification_logic.dart';
import 'package:time_tracker/core/services/settings_service.dart';

void main() {
  const defaultSettings = NotificationSettings(
    sleepStartMinute: 1380, // 23:00
    sleepEndMinute: 420,    // 07:00
  );

  group('NotificationLogic.fallbackFireMinute', () {
    test('취침 2시간 전 반환', () {
      expect(
        NotificationLogic.fallbackFireMinute(defaultSettings),
        1260, // 21:00
      );
    });

    test('취침 01:00 → 폴백 23:00 (자정 넘김 처리)', () {
      const s = NotificationSettings(sleepStartMinute: 60); // 01:00
      expect(NotificationLogic.fallbackFireMinute(s), 1380); // 23:00
    });

    test('취침 02:00 → 폴백 00:00', () {
      const s = NotificationSettings(sleepStartMinute: 120); // 02:00
      expect(NotificationLogic.fallbackFireMinute(s), 0); // 00:00
    });
  });

  group('NotificationLogic.inSleepWindow', () {
    test('취침 시간 중간 → true', () {
      expect(NotificationLogic.inSleepWindow(60, defaultSettings), isTrue); // 01:00
    });

    test('취침 시작 시각 → true', () {
      expect(NotificationLogic.inSleepWindow(1380, defaultSettings), isTrue);
    });

    test('취침 종료 시각 → false (exclusive)', () {
      expect(NotificationLogic.inSleepWindow(420, defaultSettings), isFalse);
    });

    test('낮 시간 → false', () {
      expect(NotificationLogic.inSleepWindow(720, defaultSettings), isFalse); // 12:00
    });

    test('취침 없음(start < end) — 낮 시간 → false', () {
      const s = NotificationSettings(sleepStartMinute: 120, sleepEndMinute: 360);
      expect(NotificationLogic.inSleepWindow(720, s), isFalse);
    });

    test('취침 없음(start < end) — 취침 중 → true', () {
      const s = NotificationSettings(sleepStartMinute: 120, sleepEndMinute: 360);
      expect(NotificationLogic.inSleepWindow(240, s), isTrue);
    });
  });
}
