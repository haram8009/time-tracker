import 'notification_settings.dart';

/// 알림 스케줄 관련 순수 계산 로직. 플러그인 의존 없음 → 단위 테스트 가능.
class NotificationLogic {
  /// 폴백 알림 발화 시각 (분): 취침 시작 2시간 전.
  static int fallbackFireMinute(NotificationSettings s) {
    final target = s.sleepStartMinute - 120;
    return target < 0 ? target + 1440 : target;
  }

  /// [minute]이 취침 시간대(sleepStart~sleepEnd)에 속하는지 여부.
  static bool inSleepWindow(int minute, NotificationSettings s) {
    final start = s.sleepStartMinute;
    final end = s.sleepEndMinute;
    if (start > end) {
      return minute >= start || minute < end;
    }
    return minute >= start && minute < end;
  }
}
