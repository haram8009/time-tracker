import '../models/time_block.dart';
import 'notification_logic.dart';
import 'notification_port.dart';
import 'notification_settings.dart';

const _notifId = 1;
const _gapMinutes = 180; // 3시간
const _fallbackBaseId = 100;
const _fallbackDays = 7;

/// 오늘 블록 목록 + 설정 기반으로 알림 예약 (또는 취소).
Future<void> scheduleSmartNotification({
  required List<TimeBlock> todayBlocks,
  required NotificationSettings settings,
  required NotificationPort port,
}) async {
  await port.cancelById(_notifId);

  if (!settings.enabled) return;

  final lastEnd = todayBlocks.isEmpty
      ? null
      : todayBlocks.map((b) => b.endMinute).reduce((a, b) => a > b ? a : b);

  final now = DateTime.now();
  final nowMinute = now.hour * 60 + now.minute;

  final targetMinute = (lastEnd ?? nowMinute) + _gapMinutes;

  if (NotificationLogic.inSleepWindow(targetMinute, settings)) return;
  if (targetMinute <= nowMinute) return;

  final fireTime = DateTime(
    now.year,
    now.month,
    now.day,
    targetMinute ~/ 60,
    targetMinute % 60,
  );

  await port.scheduleAtTime(
    id: _notifId,
    title: '시간 기록을 잊으셨나요?',
    body: '마지막 기록 후 ${_gapMinutes ~/ 60}시간이 지났어요. 지금 기록해 보세요.',
    fireTime: fireTime,
  );
}

/// 앱 미실행 날을 위한 폴백 알림 (취침 2시간 전 고정 시간, 7일치).
/// 앱이 열리면 당일 스마트 알림(ID 1)이 덮어씀.
Future<void> scheduleWeeklyFallbackNotifications(
  NotificationSettings settings,
  NotificationPort port,
) async {
  for (var i = 0; i < _fallbackDays; i++) {
    await port.cancelById(_fallbackBaseId + i);
  }
  if (!settings.enabled) return;

  final now = DateTime.now();
  final fireMinute = NotificationLogic.fallbackFireMinute(settings);

  for (var day = 1; day <= _fallbackDays; day++) {
    if (NotificationLogic.inSleepWindow(fireMinute, settings)) continue;
    final fireDate = DateTime(
      now.year,
      now.month,
      now.day + day,
      fireMinute ~/ 60,
      fireMinute % 60,
    );
    await port.scheduleAtTime(
      id: _fallbackBaseId + day - 1,
      title: '오늘 시간 기록을 남겨보세요',
      body: '하루 마무리 전에 오늘 활동을 기록해 보세요.',
      fireTime: fireDate,
    );
  }
}
