import 'remote_records.dart';

/// Abstraction over the remote (Supabase) data store. All writes are
/// idempotent upserts keyed by primary key, so re-running promotion never
/// creates duplicate rows; reads return every row owned by [ownerId]
/// (tombstoned rows included — callers decide how to apply them). Kept behind
/// a port so the sync services are testable without live network calls.
abstract interface class CloudSyncPort {
  Future<void> upsertCategory(RemoteCategory category);
  Future<void> upsertTimeBlock(RemoteTimeBlock block);
  Future<void> upsertSettings(RemoteSettings settings);

  Future<List<RemoteCategory>> fetchCategories(String ownerId);
  Future<List<RemoteTimeBlock>> fetchTimeBlocks(String ownerId);
  Future<RemoteSettings?> fetchSettings(String ownerId);
}
