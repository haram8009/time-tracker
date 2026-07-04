import 'remote_records.dart';

/// Abstraction over the remote (Supabase) data store. All operations are
/// idempotent upserts keyed by primary key, so re-running promotion never
/// creates duplicate rows. Kept behind a port so the promotion service is
/// testable without live network calls.
abstract interface class CloudSyncPort {
  Future<void> upsertCategory(RemoteCategory category);
  Future<void> upsertTimeBlock(RemoteTimeBlock block);
  Future<void> upsertSettings(RemoteSettings settings);
}
