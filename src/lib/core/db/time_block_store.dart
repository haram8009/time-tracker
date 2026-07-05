import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../logic/block_replace_reducer.dart';
import '../models/date_key.dart';
import '../models/time_block.dart';
import 'database_helper.dart';
import 'sync_metadata.dart';

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class TimeBlockStore {
  TimeBlockStore(this._db);

  final Database _db;

  // One broadcast controller per date that has active listeners.
  final _controllers = <String, StreamController<List<TimeBlock>>>{};

  final _changesController = StreamController<void>.broadcast();

  /// Emits whenever any block is inserted, updated, or deleted.
  Stream<void> get changes => _changesController.stream;

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<List<TimeBlock>> fetchByDate(DateKey date) async {
    final rows = await _db.query(
      'time_blocks',
      where: 'date = ? AND deletedAt IS NULL',
      whereArgs: [date.toDbString()],
      orderBy: 'startMinute ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Future<int> countByCategory(int categoryId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM time_blocks '
      'WHERE categoryId = ? AND deletedAt IS NULL',
      [categoryId],
    );
    return result.first['cnt'] as int;
  }

  Future<List<TimeBlock>> fetchByDateRange(DateKey from, DateKey to) async {
    final rows = await _db.query(
      'time_blocks',
      where: 'date >= ? AND date <= ? AND deletedAt IS NULL',
      whereArgs: [from.toDbString(), to.toDbString()],
      orderBy: 'date ASC, startMinute ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Stream<List<TimeBlock>> watchByDate(DateKey date) {
    final key = date.toDbString();
    final controller = _controllers.putIfAbsent(
      key,
      () => StreamController<List<TimeBlock>>.broadcast(
        onCancel: () => _controllers.remove(key),
      ),
    );

    // Emit current snapshot immediately.
    fetchByDate(date).then((list) {
      if (!controller.isClosed) controller.add(list);
    });

    return controller.stream;
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<TimeBlock> insert(TimeBlock block) async {
    final id = await _db.insert(
      'time_blocks',
      stampPending(block.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final created = block.copyWith(id: id);
    await _notify(block.date);
    return created;
  }

  /// Replaces [startMinute, endMinute) with [block], handling all overlap cases
  /// and merging adjacent same-category blocks (ADR-0002).
  Future<TimeBlock> replaceRange(TimeBlock block) async {
    final existing = await fetchByDate(block.date);
    final ops = applyBlockReplace(existing, block);

    await _db.transaction((txn) async {
      for (final op in ops) {
        switch (op) {
          case InsertOp(:final block):
            await txn.insert('time_blocks', stampPending(block.toMap()),
                conflictAlgorithm: ConflictAlgorithm.replace);
          case UpdateOp(:final block):
            await txn.update('time_blocks', stampPending(block.toMap()),
                where: 'id = ?', whereArgs: [block.id]);
          case DeleteOp(:final id):
            await _deleteOrTombstone(txn, id);
        }
      }
    });

    await _notify(block.date);
    return block;
  }

  Future<void> update(TimeBlock block) async {
    assert(block.id != null, 'Cannot update a TimeBlock without an id');
    await _db.update(
      'time_blocks',
      stampPending(block.toMap()),
      where: 'id = ?',
      whereArgs: [block.id],
    );
    await _notify(block.date);
  }

  Future<void> delete(int id) async {
    final rows = await _db.query(
      'time_blocks',
      columns: ['date'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await _deleteOrTombstone(_db, id);
    if (rows.isNotEmpty) {
      await _notify(DateKey.fromDbString(rows.first['date'] as String));
    }
  }

  /// Rows the cloud already knows (remoteId set) become pending tombstones so
  /// the delete propagates on the next sync; never-synced rows are removed
  /// outright — no remote counterpart could resurrect them.
  Future<void> _deleteOrTombstone(DatabaseExecutor db, int id) async {
    final tombstoned = await db.update(
      'time_blocks',
      stampPending({
        SyncColumns.deletedAt: DateTime.now().toUtc().toIso8601String(),
      }),
      where: 'id = ? AND remoteId IS NOT NULL',
      whereArgs: [id],
    );
    if (tombstoned == 0) {
      await db.delete('time_blocks', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Re-emits [changes] and every active per-date watcher after external
  /// writes (e.g. cloud pull) that bypass the store's mutation methods.
  Future<void> refreshWatchers() async {
    if (!_changesController.isClosed) _changesController.add(null);
    for (final key in _controllers.keys.toList()) {
      final controller = _controllers[key];
      if (controller == null || controller.isClosed) continue;
      final list = await fetchByDate(DateKey.fromDbString(key));
      if (!controller.isClosed) controller.add(list);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _notify(DateKey date) async {
    if (!_changesController.isClosed) _changesController.add(null);
    final controller = _controllers[date.toDbString()];
    if (controller == null || controller.isClosed) return;
    final list = await fetchByDate(date);
    controller.add(list);
  }

  void dispose() {
    _changesController.close();
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final timeBlockStoreProvider = Provider<TimeBlockStore>((ref) {
  final db = ref.watch(databaseProvider);
  final store = TimeBlockStore(db);
  ref.onDispose(store.dispose);
  return store;
});

/// Reactive stream of time blocks for a specific date.
final timeBlocksStreamProvider =
    StreamProvider.family<List<TimeBlock>, DateKey>((ref, date) {
  return ref.watch(timeBlockStoreProvider).watchByDate(date);
});

/// Reactive stream of blocks between two YYYY-MM-DD dates (inclusive).
/// Re-fetches whenever any block is inserted, updated, or deleted.
final timeBlocksRangeProvider =
    StreamProvider.family<List<TimeBlock>, (DateKey, DateKey)>((ref, range) async* {
  final store = ref.watch(timeBlockStoreProvider);
  yield await store.fetchByDateRange(range.$1, range.$2);
  await for (final _ in store.changes) {
    yield await store.fetchByDateRange(range.$1, range.$2);
  }
});
