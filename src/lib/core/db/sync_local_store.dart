import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'sync_metadata.dart';

/// Reads/writes local sync metadata for promotion and future incremental sync.
/// Works directly on the SQLite rows so it can stamp remote identity without
/// threading sync fields through the domain models.
class SyncLocalStore {
  final Database _db;

  SyncLocalStore(this._db);

  Future<List<Map<String, Object?>>> pendingCategories() => _db.query(
        'categories',
        where: 'syncStatus = ?',
        whereArgs: [SyncColumns.pending],
        orderBy: 'id ASC',
      );

  Future<List<Map<String, Object?>>> pendingTimeBlocks() => _db.query(
        'time_blocks',
        where: 'syncStatus = ?',
        whereArgs: [SyncColumns.pending],
        orderBy: 'id ASC',
      );

  /// Local category id -> remote uuid, for every category already carrying a
  /// remote id (used to resolve a block's remote category reference).
  Future<Map<int, String>> categoryRemoteIds() async {
    final rows = await _db.query(
      'categories',
      columns: ['id', 'remoteId'],
      where: 'remoteId IS NOT NULL',
    );
    return {
      for (final r in rows) r['id'] as int: r['remoteId'] as String,
    };
  }

  /// Assigns remote identity while keeping the row pending, so a crash before
  /// [markCategorySynced] lets a retry reuse the same uuid (no duplicate).
  Future<void> assignCategoryRemote(
    int localId,
    String remoteId,
    String ownerId,
  ) =>
      _db.update(
        'categories',
        {SyncColumns.remoteId: remoteId, SyncColumns.ownerId: ownerId},
        where: 'id = ?',
        whereArgs: [localId],
      );

  Future<void> markCategorySynced(int localId) => _db.update(
        'categories',
        {SyncColumns.syncStatus: SyncColumns.synced},
        where: 'id = ?',
        whereArgs: [localId],
      );

  Future<void> assignTimeBlockRemote(
    int localId,
    String remoteId,
    String ownerId,
  ) =>
      _db.update(
        'time_blocks',
        {SyncColumns.remoteId: remoteId, SyncColumns.ownerId: ownerId},
        where: 'id = ?',
        whereArgs: [localId],
      );

  Future<void> markTimeBlockSynced(int localId) => _db.update(
        'time_blocks',
        {SyncColumns.syncStatus: SyncColumns.synced},
        where: 'id = ?',
        whereArgs: [localId],
      );

  /// Local category rows keyed by remote uuid, for reconciling pulled data.
  Future<Map<String, Map<String, Object?>>> categoriesByRemoteId() =>
      _rowsByRemoteId('categories');

  /// Local time_block rows keyed by remote uuid.
  Future<Map<String, Map<String, Object?>>> timeBlocksByRemoteId() =>
      _rowsByRemoteId('time_blocks');

  Future<Map<String, Map<String, Object?>>> _rowsByRemoteId(
      String table) async {
    final rows = await _db.query(table, where: 'remoteId IS NOT NULL');
    return {
      for (final r in rows) r[SyncColumns.remoteId] as String: r,
    };
  }

  /// Inserts or updates a local category from pulled remote [values] (caller
  /// stamps them synced — pulled rows must not echo back to the cloud).
  /// Targets the row already carrying [remoteId], or [adoptLocalId] when a
  /// local-only row takes over the remote identity, else inserts a new row.
  /// Returns the local id.
  Future<int> upsertCategoryFromRemote(
    String remoteId,
    Map<String, Object?> values, {
    int? adoptLocalId,
  }) =>
      _upsertFromRemote('categories', remoteId, values,
          adoptLocalId: adoptLocalId);

  /// Same as [upsertCategoryFromRemote] for time_blocks.
  Future<int> upsertTimeBlockFromRemote(
    String remoteId,
    Map<String, Object?> values,
  ) =>
      _upsertFromRemote('time_blocks', remoteId, values);

  Future<int> _upsertFromRemote(
    String table,
    String remoteId,
    Map<String, Object?> values, {
    int? adoptLocalId,
  }) async {
    if (adoptLocalId != null) {
      await _db.update(table, values, where: 'id = ?', whereArgs: [adoptLocalId]);
      return adoptLocalId;
    }
    final updated = await _db
        .update(table, values, where: 'remoteId = ?', whereArgs: [remoteId]);
    if (updated > 0) {
      final row = await _db.query(table,
          columns: ['id'], where: 'remoteId = ?', whereArgs: [remoteId]);
      return row.single['id'] as int;
    }
    return _db.insert(table, values);
  }
}

final syncLocalStoreProvider = Provider<SyncLocalStore>(
  (ref) => SyncLocalStore(ref.watch(databaseProvider)),
);
