import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/time_block.dart';
import '../services/settings_service.dart';

final _plugin = FlutterLocalNotificationsPlugin();

const _notifId = 1;
const _gapMinutes = 180; // 3시간

Future<void> initNotifications() async {
  tz_data.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: iOS),
  );
}

/// 오늘 블록 목록 + 설정 기반으로 알림 예약 (또는 취소).
Future<void> scheduleSmartNotification({
  required List<TimeBlock> todayBlocks,
  required NotificationSettings settings,
}) async {
  await _plugin.cancel(_notifId);

  if (!settings.enabled) return;

  final lastEnd = todayBlocks.isEmpty
      ? null
      : todayBlocks.map((b) => b.endMinute).reduce((a, b) => a > b ? a : b);

  final now = DateTime.now();
  final nowMinute = now.hour * 60 + now.minute;

  final targetMinute = (lastEnd ?? nowMinute) + _gapMinutes;

  // 취침 시간 내 → 알림 없음
  if (_inSleepWindow(targetMinute, settings)) return;

  // 이미 지났으면 스케줄 불필요
  if (targetMinute <= nowMinute) return;

  final fireTime = DateTime(
    now.year,
    now.month,
    now.day,
    targetMinute ~/ 60,
    targetMinute % 60,
  );

  await _plugin.zonedSchedule(
    _notifId,
    '시간 기록을 잊으셨나요?',
    '마지막 기록 후 ${_gapMinutes ~/ 60}시간이 지났어요. 지금 기록해 보세요.',
    tz.TZDateTime.from(fireTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'time_tracker_smart',
        '스마트 알림',
        channelDescription: '3시간 이상 기록 공백 감지 시 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

bool _inSleepWindow(int minute, NotificationSettings s) {
  final start = s.sleepStartMinute;
  final end = s.sleepEndMinute;
  // sleep wraps midnight (e.g. 1380~420)
  if (start > end) {
    return minute >= start || minute < end;
  }
  return minute >= start && minute < end;
}
