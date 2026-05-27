import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import 'database_helper.dart';

// ---------------------------------------------------------------------------
// Preset data
// ---------------------------------------------------------------------------

const _presets = [
  Category(name: '수면', colorHex: '#5C6BC0', isPreset: true),
  Category(name: '업무', colorHex: '#EF5350', isPreset: true),
  Category(name: '운동', colorHex: '#66BB6A', isPreset: true),
  Category(name: '식사', colorHex: '#FFA726', isPreset: true),
  Category(name: '이동', colorHex: '#26C6DA', isPreset: true),
  Category(name: '여가', colorHex: '#AB47BC', isPreset: true),
];

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class CategoryStore {
  CategoryStore({this._seedCategories});

  final List<Category>? _seedCategories;
  final _controller = StreamController<List<Category>>.broadcast();

  Future<Database> get _db => DatabaseHelper.instance.database;

  late final Future<void> _ready = _doSeedIfNeeded();

  Future<void> _doSeedIfNeeded() async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'isPreset = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      final seeds = _seedCategories ?? _presets;
      final batch = db.batch();
      for (final preset in seeds) {
        batch.insert('categories', preset.toMap());
      }
      await batch.commit(noResult: true);
    }
  }

  // ── Seeding ──────────────────────────────────────────────────────────────

  Future<void> seedIfNeeded() => _ready;

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<List<Category>> fetchAll() async {
    await _ready;
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'id ASC');
    return rows.map(Category.fromMap).toList();
  }

  Stream<List<Category>> watchAll() {
    // Emit current snapshot immediately, then re-emit on every mutation.
    fetchAll().then((list) {
      if (!_controller.isClosed) _controller.add(list);
    });
    return _controller.stream;
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<Category> insert(Category category) async {
    final db = await _db;
    final id = await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final created = category.copyWith(id: id);
    await _notify();
    return created;
  }

  Future<void> update(Category category) async {
    assert(category.id != null, 'Cannot update a Category without an id');
    final db = await _db;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await _notify();
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _notify();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _notify() async {
    final list = await fetchAll();
    if (!_controller.isClosed) _controller.add(list);
  }

  void dispose() {
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final categoryStoreProvider = Provider<CategoryStore>((ref) {
  final store = CategoryStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Reactive stream of all categories.
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryStoreProvider).watchAll();
});
