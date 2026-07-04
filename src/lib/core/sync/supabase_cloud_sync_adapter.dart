import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_sync_port.dart';
import 'remote_records.dart';

/// Real [CloudSyncPort] backed by Supabase Postgres upserts. Not unit-tested —
/// it performs live network calls; the promotion service is tested with a fake.
class SupabaseCloudSyncAdapter implements CloudSyncPort {
  final SupabaseClient _client;

  SupabaseCloudSyncAdapter(this._client);

  @override
  Future<void> upsertCategory(RemoteCategory category) async {
    // Conflict on the primary key (id) makes re-promotion idempotent.
    await _client.from('categories').upsert(category.toMap());
  }

  @override
  Future<void> upsertTimeBlock(RemoteTimeBlock block) async {
    await _client.from('time_blocks').upsert(block.toMap());
  }

  @override
  Future<void> upsertSettings(RemoteSettings settings) async {
    await _client
        .from('user_settings')
        .upsert(settings.toMap(), onConflict: 'owner_id');
  }

  @override
  Future<List<RemoteCategory>> fetchCategories(String ownerId) async {
    final rows =
        await _client.from('categories').select().eq('owner_id', ownerId);
    return rows.map(RemoteCategory.fromMap).toList();
  }

  @override
  Future<List<RemoteTimeBlock>> fetchTimeBlocks(String ownerId) async {
    final rows =
        await _client.from('time_blocks').select().eq('owner_id', ownerId);
    return rows.map(RemoteTimeBlock.fromMap).toList();
  }

  @override
  Future<RemoteSettings?> fetchSettings(String ownerId) async {
    final row = await _client
        .from('user_settings')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null ? null : RemoteSettings.fromMap(row);
  }
}
