import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/time_block.dart';
import 'database_helper.dart';

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class TimeBlockStore {
  // One broadcast controller per date that has active listeners.
  final _controllers = <String, StreamController<List<TimeBlock>>>{};

  final _changesController = StreamController<void>.broadcast();

  /// Emits whenever any block is inserted, updated, or deleted.
  Stream<void> get changes => _changesController.stream;

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<List<TimeBlock>> fetchByDate(String date) async {
    final db = await _db;
    final rows = await db.query(
      'time_blocks',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'startMinute ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Future<int> countByCategory(int categoryId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM time_blocks WHERE categoryId = ?',
      [categoryId],
    );
    return result.first['cnt'] as int;
  }

  Future<List<TimeBlock>> fetchByDateRange(String from, String to) async {
    final db = await _db;
    final rows = await db.query(
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
    final db = await _db;
    final id = await db.insert(
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
    final db = await _db;
    late TimeBlock result;

    await db.transaction((txn) async {
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

  /// Replaces [startMinute, endMinute) with [block], handling all overlap cases:
  /// - blocks fully inside the range are deleted
  /// - blocks partially overlapping are trimmed
  /// - blocks straddling the range are split
  /// After clearing the range, merges with adjacent same-category blocks.
  Future<TimeBlock> replaceRange(TimeBlock block) async {
    final db = await _db;
    late TimeBlock result;

    await db.transaction((txn) async {
      final overlappingRows = await txn.query(
        'time_blocks',
        where: 'date = ? AND startMinute < ? AND endMinute > ?',
        whereArgs: [block.date, block.endMinute, block.startMinute],
      );

      for (final row in overlappingRows) {
        final existing = TimeBlock.fromMap(row);
        final leftOverhang = existing.startMinute < block.startMinute;
        final rightOverhang = existing.endMinute > block.endMinute;

        if (leftOverhang && rightOverhang) {
          await txn.update(
            'time_blocks',
            existing.copyWith(endMinute: block.startMinute).toMap(),
            where: 'id = ?',
            whereArgs: [existing.id],
          );
          await txn.insert(
            'time_blocks',
            TimeBlock(
              date: existing.date,
              startMinute: block.endMinute,
              endMinute: existing.endMinute,
              categoryId: existing.categoryId,
              note: existing.note,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else if (leftOverhang) {
          await txn.update(
            'time_blocks',
            existing.copyWith(endMinute: block.startMinute).toMap(),
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        } else if (rightOverhang) {
          await txn.update(
            'time_blocks',
            existing.copyWith(startMinute: block.endMinute).toMap(),
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        } else {
          await txn.delete(
              'time_blocks', where: 'id = ?', whereArgs: [existing.id]);
        }
      }

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

      final prev =
          prevRows.isNotEmpty ? TimeBlock.fromMap(prevRows.first) : null;
      final next =
          nextRows.isNotEmpty ? TimeBlock.fromMap(nextRows.first) : null;

      if (prev != null && next != null) {
        final merged = prev.copyWith(endMinute: next.endMinute);
        await txn.update('time_blocks', merged.toMap(),
            where: 'id = ?', whereArgs: [prev.id]);
        await txn.delete('time_blocks',
            where: 'id = ?', whereArgs: [next.id]);
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
        final blockToInsert =
            block.id != null ? block.copyWith(id: null) : block;
        final id = await txn.insert('time_blocks', blockToInsert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        result = block.copyWith(id: id);
      }
    });

    await _notify(block.date);
    return result;
  }

  Future<void> update(TimeBlock block) async {
    assert(block.id != null, 'Cannot update a TimeBlock without an id');
    final db = await _db;
    await db.update(
      'time_blocks',
      block.toMap(),
      where: 'id = ?',
      whereArgs: [block.id],
    );
    await _notify(block.date);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    // Fetch date before deletion so we can notify the right stream.
    final rows = await db.query(
      'time_blocks',
      columns: ['date'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('time_blocks', where: 'id = ?', whereArgs: [id]);
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
  final store = TimeBlockStore();
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
