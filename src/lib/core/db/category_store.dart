import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../services/preferences_port.dart';
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

const _kSeedKey = 'categories_seeded';

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class CategoryStore {
  CategoryStore({this._seedCategories, this._prefs});

  final List<Category>? _seedCategories;
  final PreferencesPort? _prefs;
  final _controller = StreamController<List<Category>>.broadcast();
  final _allController = StreamController<List<Category>>.broadcast();

  Future<Database> get _db => DatabaseHelper.instance.database;

  late final Future<void> _ready = _doSeedIfNeeded();

  Future<void> _doSeedIfNeeded() async {
    // Skip if already seeded (first-install flag set).
    if (_prefs?.getBool(_kSeedKey) == true) return;

    final db = await _db;
    final rows = await db.query('categories', limit: 1);
    if (rows.isEmpty) {
      final seeds = _seedCategories ?? _presets;
      final batch = db.batch();
      for (final preset in seeds) {
        batch.insert('categories', preset.toMap());
      }
      await batch.commit(noResult: true);
    }

    await _prefs?.setBool(_kSeedKey, true);
  }

  // ── Seeding ──────────────────────────────────────────────────────────────

  Future<void> seedIfNeeded() => _ready;

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<List<Category>> fetchAll() async {
    await _ready;
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'isHidden = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Category>> fetchAllIncludingRetired() async {
    await _ready;
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'id ASC');
    return rows.map(Category.fromMap).toList();
  }

  Stream<List<Category>> watchAll() {
    fetchAll().then((list) {
      if (!_controller.isClosed) _controller.add(list);
    });
    return _controller.stream;
  }

  Stream<List<Category>> watchAllIncludingRetired() {
    fetchAllIncludingRetired().then((list) {
      if (!_allController.isClosed) _allController.add(list);
    });
    return _allController.stream;
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

  /// Soft-deletes a category — hides it from the selection list without
  /// removing the DB row (preserves TimeBlock references).
  Future<void> retire(int id) async {
    final db = await _db;
    await db.update(
      'categories',
      {'isHidden': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notify();
  }

  /// Hard-deletes a category and all its TimeBlocks in a single transaction.
  Future<void> deleteWithRecords(int categoryId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('time_blocks',
          where: 'categoryId = ?', whereArgs: [categoryId]);
      await txn.delete('categories',
          where: 'id = ?', whereArgs: [categoryId]);
    });
    await _notify();
  }

  /// Un-hides all preset categories.
  Future<void> restoreDefaults() async {
    final db = await _db;
    await db.update(
      'categories',
      {'isHidden': 0},
      where: 'isPreset = ?',
      whereArgs: [1],
    );
    await _notify();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _notify() async {
    final list = await fetchAll();
    if (!_controller.isClosed) _controller.add(list);
    final allList = await fetchAllIncludingRetired();
    if (!_allController.isClosed) _allController.add(allList);
  }

  void dispose() {
    _controller.close();
    _allController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final categoryStoreProvider = Provider<CategoryStore>((ref) {
  final prefs = ref.watch(sharedPrefsAdapterProvider);
  final store = CategoryStore(prefs: prefs);
  ref.onDispose(store.dispose);
  return store;
});

/// Reactive stream of visible categories (isHidden=0).
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryStoreProvider).watchAll();
});

/// Reactive stream of all categories including RetiredCategories.
final categoriesAllStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryStoreProvider).watchAllIncludingRetired();
});
