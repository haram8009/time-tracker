import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/time_block_store.dart';
import '../models/date_key.dart';
import '../models/time_block.dart';
import '../notifications/notification_port.dart';
import '../notifications/notification_scheduler.dart';
import 'settings_service.dart';

class BlockSaveInteractor {
  const BlockSaveInteractor({
    required this.store,
    required this.notificationPort,
    required this.settings,
  });

  final TimeBlockStore store;
  final NotificationPort notificationPort;
  final NotificationSettings settings;

  Future<void> save(TimeBlock block) async {
    await store.replaceRange(block);

    final today = DateKey.today();
    final todayKey = today.toDbString();
    if (block.date == todayKey) {
      final todayBlocks = await store.fetchByDate(today);
      await scheduleSmartNotification(
        todayBlocks: todayBlocks,
        settings: settings,
        port: notificationPort,
      );
    }
  }
}

final blockSaveInteractorProvider = Provider<BlockSaveInteractor>((ref) {
  return BlockSaveInteractor(
    store: ref.watch(timeBlockStoreProvider),
    notificationPort: ref.watch(notificationPortProvider),
    settings: ref.watch(settingsServiceProvider),
  );
});
