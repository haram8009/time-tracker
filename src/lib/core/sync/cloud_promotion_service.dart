// ignore_for_file: prefer_initializing_formals
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/sync_local_store.dart';
import '../db/sync_metadata.dart';
import '../notifications/notification_settings.dart';
import '../services/preferences_port.dart';
import 'cloud_sync_port.dart';
import 'remote_records.dart';
import 'uuid_v4.dart';

/// Promotes existing guest-local data to the signed-in user's cloud rows on the
/// first successful sync. Ordering matters: categories first so blocks can
/// reference their remote category uuid.
///
/// Idempotency & partial-failure safety: a remote id is assigned and persisted
/// locally *before* the cloud upsert. If a later step fails, the row stays
/// pending with its id already set, so a retry reuses the same id and the
/// primary-key upsert cannot create a duplicate.
class CloudPromotionService {
  final SyncLocalStore _local;
  final CloudSyncPort _cloud;
  final PreferencesPort _prefs;
  final String Function() _newId;

  CloudPromotionService({
    required SyncLocalStore local,
    required CloudSyncPort cloud,
    required PreferencesPort prefs,
    String Function()? newId,
  })  : _local = local,
        _cloud = cloud,
        _prefs = prefs,
        _newId = newId ?? generateUuidV4;

  Future<void> promote(String ownerId) async {
    await _promoteCategories(ownerId);
    await _promoteTimeBlocks(ownerId);
    await _promoteSettings(ownerId);
  }

  Future<void> _promoteCategories(String ownerId) async {
    for (final row in await _local.pendingCategories()) {
      final localId = row['id'] as int;
      final remoteId = (row['remoteId'] as String?) ?? _newId();

      await _local.assignCategoryRemote(localId, remoteId, ownerId);
      await _cloud.upsertCategory(RemoteCategory(
        id: remoteId,
        ownerId: ownerId,
        name: row['name'] as String,
        colorHex: row['colorHex'] as String,
        isPreset: (row['isPreset'] as int) == 1,
        isHidden: (row['isHidden'] as int) == 1,
        sortOrder: localId,
        updatedAt: _timestamp(row['updatedAt'] as String?),
        deletedAt: row['deletedAt'] as String?,
      ));
      await _local.markCategorySynced(localId);
    }
  }

  Future<void> _promoteTimeBlocks(String ownerId) async {
    final categoryRemoteIds = await _local.categoryRemoteIds();

    for (final row in await _local.pendingTimeBlocks()) {
      final localId = row['id'] as int;
      final remoteCategoryId = categoryRemoteIds[row['categoryId'] as int];
      // A block whose category has no remote id yet cannot be promoted; leave
      // it pending for a later run.
      if (remoteCategoryId == null) continue;

      final remoteId = (row['remoteId'] as String?) ?? _newId();

      await _local.assignTimeBlockRemote(localId, remoteId, ownerId);
      await _cloud.upsertTimeBlock(RemoteTimeBlock(
        id: remoteId,
        ownerId: ownerId,
        categoryId: remoteCategoryId,
        date: row['date'] as String,
        startMinute: row['startMinute'] as int,
        endMinute: row['endMinute'] as int,
        note: row['note'] as String?,
        updatedAt: _timestamp(row['updatedAt'] as String?),
        deletedAt: row['deletedAt'] as String?,
      ));
      await _local.markTimeBlockSynced(localId);
    }
  }

  /// Pushes settings only when a local edit is pending, or when settings have
  /// never synced at all (no [SettingsSyncKeys] stamp — first promotion).
  /// A clean stamp means the cloud already has this state; pushing anyway
  /// would clobber a newer remote edit with a fresh timestamp.
  Future<void> _promoteSettings(String ownerId) async {
    final stampMillis = _prefs.getInt(SettingsSyncKeys.updatedAtMillis);
    final dirty = _prefs.getBool(SettingsSyncKeys.dirty) ?? false;
    if (stampMillis != null && !dirty) return;

    final updatedAtMillis =
        stampMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    await _cloud.upsertSettings(RemoteSettings(
      ownerId: ownerId,
      notificationEnabled: _prefs.getBool(NotificationSettings.keyEnabled) ??
          NotificationSettings.defaultEnabled,
      sleepStartMinute: _prefs.getInt(NotificationSettings.keySleepStart) ??
          NotificationSettings.defaultSleepStart,
      sleepEndMinute: _prefs.getInt(NotificationSettings.keySleepEnd) ??
          NotificationSettings.defaultSleepEnd,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis, isUtc: true)
          .toIso8601String(),
    ));
    await _prefs.setInt(SettingsSyncKeys.updatedAtMillis, updatedAtMillis);
    await _prefs.setBool(SettingsSyncKeys.dirty, false);
  }

  /// Uses the row's stamped timestamp, falling back to now for rows that
  /// predate stamping (empty default) — the remote column rejects blanks.
  String _timestamp(String? value) => (value == null || value.isEmpty)
      ? DateTime.now().toUtc().toIso8601String()
      : value;
}

/// Overridden in main.dart with the real Supabase adapter when cloud sync is
/// configured. Never read in guest-only builds (sign-in is impossible there).
final cloudSyncPortProvider = Provider<CloudSyncPort>(
  (ref) => throw UnimplementedError('cloudSyncPortProvider must be overridden'),
);

final cloudPromotionServiceProvider = Provider<CloudPromotionService>(
  (ref) => CloudPromotionService(
    local: ref.watch(syncLocalStoreProvider),
    cloud: ref.watch(cloudSyncPortProvider),
    prefs: ref.watch(sharedPrefsAdapterProvider),
  ),
);
