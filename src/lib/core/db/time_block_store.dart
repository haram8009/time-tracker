import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../logic/block_replace_reducer.dart';
import '../models/time_block.dart';
import 'database_helper.dart';

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

  Future<List<TimeBlock>> fetchByDate(String date) async {
    final rows = await _db.query(
      'time_blocks',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'startMinute ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Future<int> countByCategory(int categoryId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM time_blocks WHERE categoryId = ?',
      [categoryId],
    );
    return result.first['cnt'] as int;
  }

  Future<List<TimeBlock>> fetchByDateRange(String from, String to) async {
    final rows = await _db.query(
      'time_blocks',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
      orderBy: 'date ASC, startMinute ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Stream<List<TimeBlock>> watchByDate(String date) {
    final controller = _controllers.putIfAbsent(
      date,
      () => StreamController<List<TimeBlock>>.broadcast(
        onCancel: () => _controllers.remove(date),
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
      block.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final created = block.copyWith(id: id);
    await _notify(block.date);
    return created;
  }

  /// Inserts [block], merging with adjacent same-category blocks if present.
  Future<TimeBlock> mergeOrInsert(TimeBlock block) async {
    late TimeBlock result;

    await _db.transaction((txn) async {
      final prevRows = await txn.query(
        'time_blocks',
        where: 'date = ? AND categoryId = ? AND endMinute = ?',
        whereArgs: [block.date, block.categoryId, block.startMinute],
        limit: 1,
      );
      final nextRows = await txn.query(
        'time_blocks',
        where: 'date = ? AND categoryId = ? AND startMinute = ?',
        whereArgs: [block.date, block.categoryId, block.endMinute],
        limit: 1,
      );

      final prev = prevRows.isNotEmpty ? TimeBlock.fromMap(prevRows.first) : null;
      final next = nextRows.isNotEmpty ? TimeBlock.fromMap(nextRows.first) : null;

      if (prev != null && next != null) {
        final merged = prev.copyWith(endMinute: next.endMinute);
        await txn.update('time_blocks', merged.toMap(),
            where: 'id = ?', whereArgs: [prev.id]);
        await txn.delete('time_blocks', where: 'id = ?', whereArgs: [next.id]);
        result = merged;
      } else if (prev != null) {
        final extended = prev.copyWith(endMinute: block.endMinute);
        await txn.update('time_blocks', extended.toMap(),
            where: 'id = ?', whereArgs: [prev.id]);
        result = extended;
      } else if (next != null) {
        final extended = next.copyWith(startMinute: block.startMinute);
        await txn.update('time_blocks', extended.toMap(),
            where: 'id = ?', whereArgs: [next.id]);
        result = extended;
      } else {
        final id = await txn.insert('time_blocks', block.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        result = block.copyWith(id: id);
      }
    });

    await _notify(block.date);
    return result;
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
            await txn.insert('time_blocks', block.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          case UpdateOp(:final block):
            await txn.update('time_blocks', block.toMap(),
                where: 'id = ?', whereArgs: [block.id]);
          case DeleteOp(:final id):
            await txn.delete('time_blocks', where: 'id = ?', whereArgs: [id]);
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
      block.toMap(),
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
    await _db.delete('time_blocks', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _notify(rows.first['date'] as String);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _notify(String date) async {
    if (!_changesController.isClosed) _changesController.add(null);
    final controller = _controllers[date];
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
    StreamProvider.family<List<TimeBlock>, String>((ref, date) {
  return ref.watch(timeBlockStoreProvider).watchByDate(date);
});

/// Reactive stream of blocks between two YYYY-MM-DD dates (inclusive).
/// Re-fetches whenever any block is inserted, updated, or deleted.
final timeBlocksRangeProvider =
    StreamProvider.family<List<TimeBlock>, (String, String)>((ref, range) async* {
  final store = ref.watch(timeBlockStoreProvider);
  yield await store.fetchByDateRange(range.$1, range.$2);
  await for (final _ in store.changes) {
    yield await store.fetchByDateRange(range.$1, range.$2);
  }
});
