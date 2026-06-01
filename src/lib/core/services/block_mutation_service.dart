import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/time_block_store.dart';
import '../models/date_key.dart';
import '../models/time_block.dart';
import '../notifications/notification_port.dart';
import '../notifications/notification_scheduler.dart';
import 'settings_service.dart';

class BlockMutationService {
  const BlockMutationService({
    required this.store,
    required this.notificationPort,
    required this.settings,
  });

  final TimeBlockStore store;
  final NotificationPort notificationPort;
  final NotificationSettings settings;

  Future<void> save(TimeBlock block) async {
    await store.replaceRange(block);
    await _rescheduleIfToday(block.date);
  }

  Future<void> delete(int id, DateKey date) async {
    await store.delete(id);
    await _rescheduleIfToday(date);
  }

  Future<void> update(TimeBlock block) async {
    await store.update(block);
    await _rescheduleIfToday(block.date);
  }

  Future<void> _rescheduleIfToday(DateKey date) async {
    if (date == DateKey.today()) {
      final todayBlocks = await store.fetchByDate(DateKey.today());
      await scheduleSmartNotification(
        todayBlocks: todayBlocks,
        settings: settings,
        port: notificationPort,
      );
    }
  }
}

final blockMutationServiceProvider = Provider<BlockMutationService>((ref) {
  return BlockMutationService(
    store: ref.watch(timeBlockStoreProvider),
    notificationPort: ref.watch(notificationPortProvider),
    settings: ref.watch(settingsServiceProvider),
  );
});
