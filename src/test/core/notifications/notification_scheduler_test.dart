import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/notifications/notification_scheduler.dart';
import 'package:time_tracker/core/services/settings_service.dart';

class _FakeNotificationPort implements NotificationPort {
  final List<int> cancelledIds = [];
  final List<Map<String, dynamic>> scheduledCalls = [];

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
    scheduledCalls.add({
      'id': id,
      'title': title,
      'body': body,
      'fireTime': fireTime,
    });
  }
}

const _enabledSettings = NotificationSettings(
  enabled: true,
  sleepStartMinute: 1380, // 23:00
  sleepEndMinute: 420,    // 07:00
);

const _disabledSettings = NotificationSettings(enabled: false);

void main() {
  group('scheduleSmartNotification', () {
    test('알림 비활성 → cancel만, schedule 없음', () async {
      final port = _FakeNotificationPort();
      await scheduleSmartNotification(
        todayBlocks: [],
        settings: _disabledSettings,
        port: port,
      );
      expect(port.cancelledIds, contains(1));
      expect(port.scheduledCalls, isEmpty);
    });

    test('알림 비활성 → schedule 없음 (cancel만)', () async {
      final port = _FakeNotificationPort();
      await scheduleSmartNotification(
        todayBlocks: [],
        settings: _disabledSettings,
        port: port,
      );
      expect(port.scheduledCalls, isEmpty);
    });

    test('블록 없음 → nowMinute+3h 로 스케줄 시도 (미래라면)', () async {
      // 새벽 2시에 실행한다고 가정: nowMinute=120, target=300(5:00) → 취침 아님
      // 실제 DateTime.now()에 의존하므로 스케줄 여부는 런타임에 따라 다름
      // 여기서는 port 호출 여부만 검증
      final port = _FakeNotificationPort();
      await scheduleSmartNotification(
        todayBlocks: [],
        settings: _enabledSettings,
        port: port,
      );
      // cancelById(1) 반드시 호출
      expect(port.cancelledIds, contains(1));
    });
  });

  group('scheduleWeeklyFallbackNotifications', () {
    test('알림 비활성 → 7개 cancel, schedule 없음', () async {
      final port = _FakeNotificationPort();
      await scheduleWeeklyFallbackNotifications(_disabledSettings, port);
      expect(port.cancelledIds.length, 7);
      expect(port.scheduledCalls, isEmpty);
    });

    test('알림 활성 → 최대 7개 schedule', () async {
      final port = _FakeNotificationPort();
      await scheduleWeeklyFallbackNotifications(_enabledSettings, port);
      // 7일 중 취침 시간 제외. 21:00(1260) → 취침 아님 → 7개 스케줄
      expect(port.scheduledCalls.length, 7);
    });

    test('각 스케줄 ID = 100~106', () async {
      final port = _FakeNotificationPort();
      await scheduleWeeklyFallbackNotifications(_enabledSettings, port);
      final ids = port.scheduledCalls.map((c) => c['id'] as int).toList();
      expect(ids, [100, 101, 102, 103, 104, 105, 106]);
    });

    test('TimeBlock 있을 때 scheduleSmartNotification → port.cancelById(1) 호출', () async {
      final port = _FakeNotificationPort();
      final block = TimeBlock(
        id: 1,
        date: DateKey(2026, 1, 1),
        startMinute: 480,
        endMinute: 600,
        categoryId: 1,
      );
      await scheduleSmartNotification(
        todayBlocks: [block],
        settings: _enabledSettings,
        port: port,
      );
      expect(port.cancelledIds, contains(1));
    });
  });
}
