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
    final controller = _controllers[date];
    if (controller == null || controller.isClosed) return;
    final list = await fetchByDate(date);
    controller.add(list);
  }

  void dispose() {
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

/// One-shot fetch of blocks between two YYYY-MM-DD dates (inclusive).
final timeBlocksRangeProvider =
    FutureProvider.family<List<TimeBlock>, (String, String)>((ref, range) {
  return ref.watch(timeBlockStoreProvider).fetchByDateRange(range.$1, range.$2);
});
