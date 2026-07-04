// ignore_for_file: prefer_initializing_formals
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/sync_local_store.dart';
import '../db/sync_metadata.dart';
import '../notifications/notification_settings.dart';
import '../services/preferences_port.dart';
import 'cloud_promotion_service.dart';
import 'cloud_sync_port.dart';
import 'remote_records.dart';

/// Pulls the signed-in user's cloud rows into local SQLite (issue #93) so a
/// second device rebuilds grid/analytics/categories/settings from the cloud.
/// Categories come first so blocks can resolve their local category id
/// (remote uuid → local int — the mirror of promotion's map).
///
/// Rules until incremental sync / LWW lands (#94):
/// - Pulled rows are written synced with the remote updatedAt, bypassing
///   [stampPending], so they never echo back to the cloud.
/// - A local row that is still pending wins over its remote counterpart —
///   promotion will push it later.
/// - Tombstoned remote rows (deletedAt set) are skipped, not applied.
/// - A remote preset category with no local match by uuid adopts the local
///   seeded preset of the same name, so fresh installs don't duplicate presets.
class CloudPullService {
  final SyncLocalStore _local;
  final CloudSyncPort _cloud;
  final PreferencesPort _prefs;

  CloudPullService({
    required SyncLocalStore local,
    required CloudSyncPort cloud,
    required PreferencesPort prefs,
  })  : _local = local,
        _cloud = cloud,
        _prefs = prefs;

  Future<void> pull(String ownerId) async {
    final categoryLocalIds = await _pullCategories(ownerId);
    await _pullTimeBlocks(ownerId, categoryLocalIds);
    await _pullSettings(ownerId);
  }

  /// Returns remote category uuid → local category id for every live remote
  /// category, so the block pass can rewrite its FK.
  Future<Map<String, int>> _pullCategories(String ownerId) async {
    // Insert in remote sort order (promotion set sort_order = original local
    // id) so fresh local autoincrement ids reproduce the original ordering.
    final remotes = [...await _cloud.fetchCategories(ownerId)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final existing = await _local.categoriesByRemoteId();

    // Seeded presets without remote identity are adoption candidates.
    final adoptable = <String, int>{};
    for (final row in await _local.pendingCategories()) {
      if (row[SyncColumns.remoteId] == null && (row['isPreset'] as int) == 1) {
        adoptable[row['name'] as String] = row['id'] as int;
      }
    }

    final localIds = <String, int>{};
    for (final remote in remotes) {
      if (remote.deletedAt != null) continue;

      final current = existing[remote.id];
      if (current != null &&
          current[SyncColumns.syncStatus] == SyncColumns.pending) {
        localIds[remote.id] = current['id'] as int;
        continue;
      }

      final adoptLocalId = current == null && remote.isPreset
          ? adoptable.remove(remote.name)
          : null;
      localIds[remote.id] = await _local.upsertCategoryFromRemote(
        remote.id,
        _categoryValues(remote),
        adoptLocalId: adoptLocalId,
      );
    }
    return localIds;
  }

  Future<void> _pullTimeBlocks(
    String ownerId,
    Map<String, int> categoryLocalIds,
  ) async {
    final remotes = await _cloud.fetchTimeBlocks(ownerId);
    final existing = await _local.timeBlocksByRemoteId();

    for (final remote in remotes) {
      if (remote.deletedAt != null) continue;

      // Category unknown locally (e.g. tombstoned) — leave for a later run.
      final localCategoryId = categoryLocalIds[remote.categoryId];
      if (localCategoryId == null) continue;

      final current = existing[remote.id];
      if (current != null &&
          current[SyncColumns.syncStatus] == SyncColumns.pending) {
        continue;
      }

      await _local.upsertTimeBlockFromRemote(remote.id, {
        'date': remote.date,
        'startMinute': remote.startMinute,
        'endMinute': remote.endMinute,
        'categoryId': localCategoryId,
        'note': remote.note,
        SyncColumns.remoteId: remote.id,
        SyncColumns.ownerId: remote.ownerId,
        SyncColumns.updatedAt: remote.updatedAt,
        SyncColumns.deletedAt: remote.deletedAt,
        SyncColumns.syncStatus: SyncColumns.synced,
      });
    }
  }

  Future<void> _pullSettings(String ownerId) async {
    final remote = await _cloud.fetchSettings(ownerId);
    if (remote == null) return;

    await _prefs.setBool(
        NotificationSettings.keyEnabled, remote.notificationEnabled);
    await _prefs.setInt(
        NotificationSettings.keySleepStart, remote.sleepStartMinute);
    await _prefs.setInt(
        NotificationSettings.keySleepEnd, remote.sleepEndMinute);
  }

  Map<String, Object?> _categoryValues(RemoteCategory remote) => {
        'name': remote.name,
        'colorHex': remote.colorHex,
        'isPreset': remote.isPreset ? 1 : 0,
        'isHidden': remote.isHidden ? 1 : 0,
        SyncColumns.remoteId: remote.id,
        SyncColumns.ownerId: remote.ownerId,
        SyncColumns.updatedAt: remote.updatedAt,
        SyncColumns.deletedAt: remote.deletedAt,
        SyncColumns.syncStatus: SyncColumns.synced,
      };
}

final cloudPullServiceProvider = Provider<CloudPullService>(
  (ref) => CloudPullService(
    local: ref.watch(syncLocalStoreProvider),
    cloud: ref.watch(cloudSyncPortProvider),
    prefs: ref.watch(sharedPrefsAdapterProvider),
  ),
);
