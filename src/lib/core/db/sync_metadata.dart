/// Sync metadata contract for local SQLite rows (issue #90).
///
/// Every synced table (`categories`, `time_blocks`) carries these columns so
/// future slices can promote local rows to Supabase and reconcile them with
/// last-write-wins. Local integer ids stay local; [remoteId] maps to the
/// remote UUID once a row is promoted.
class SyncColumns {
  const SyncColumns._();

  /// Remote UUID assigned by Supabase, null until the row is promoted.
  static const remoteId = 'remoteId';

  /// Owner UUID (auth.users.id), null while the row is local-only.
  static const ownerId = 'ownerId';

  /// ISO-8601 UTC timestamp of the last local write; LWW comparison value.
  static const updatedAt = 'updatedAt';

  /// ISO-8601 UTC tombstone marker, null for live rows.
  static const deletedAt = 'deletedAt';

  /// [pending] or [synced].
  static const syncStatus = 'syncStatus';

  /// Row changed locally and still needs to be pushed to the cloud.
  static const pending = 'pending';

  /// Row is in sync with the cloud.
  static const synced = 'synced';
}

/// SharedPreferences keys tracking notification-settings sync state (settings
/// live in prefs, not SQLite, so they carry their own LWW stamp).
class SettingsSyncKeys {
  const SettingsSyncKeys._();

  /// Epoch millis (UTC) of the last local settings edit or applied remote pull.
  static const updatedAtMillis = 'settings_sync_updatedAtMillis';

  /// True while a local settings edit still needs to be pushed to the cloud.
  static const dirty = 'settings_sync_dirty';
}

/// True when [remote] (ISO-8601) is strictly newer than [local]. Timestamps
/// are parsed, not string-compared: local stamps (`...Z`, microseconds) and
/// Supabase timestamps (`...+00:00`) differ in format. Ties favor local, so a
/// pending local edit with the same stamp still pushes.
bool isRemoteNewer(String? local, String remote) {
  if (local == null || local.isEmpty) return true;
  return DateTime.parse(remote).isAfter(DateTime.parse(local));
}

/// Returns a copy of [values] stamped as a pending local write: bumps
/// [SyncColumns.updatedAt] to now (UTC) and marks [SyncColumns.syncStatus]
/// pending. Callers pass the result straight to `insert`/`update`.
Map<String, Object?> stampPending(
  Map<String, Object?> values, {
  DateTime? at,
}) {
  return {
    ...values,
    SyncColumns.updatedAt: (at ?? DateTime.now()).toUtc().toIso8601String(),
    SyncColumns.syncStatus: SyncColumns.pending,
  };
}
