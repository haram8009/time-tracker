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
}

final syncLocalStoreProvider = Provider<SyncLocalStore>(
  (ref) => SyncLocalStore(ref.watch(databaseProvider)),
);
