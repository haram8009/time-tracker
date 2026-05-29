// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/services/category_manager.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeCategoryStore extends CategoryStore {
  _FakeCategoryStore(super.db);

  final List<int> retiredIds = [];
  final List<int> deletedWithRecordsIds = [];

  @override
  Future<void> retire(int id) async {
    retiredIds.add(id);
  }

  @override
  Future<void> deleteWithRecords(int categoryId) async {
    deletedWithRecordsIds.add(categoryId);
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────────

late Database db;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              colorHex TEXT NOT NULL,
              isPreset INTEGER NOT NULL DEFAULT 0,
              isHidden INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE time_blocks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              startMinute INTEGER NOT NULL,
              endMinute INTEGER NOT NULL,
              categoryId INTEGER NOT NULL,
              note TEXT
            )
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryManager.deleteCategory', () {
    test('keepRecords: true → only retire() called', () async {
      final categoryStore = _FakeCategoryStore(db);
      final timeBlockStore = TimeBlockStore(db);
      final manager = CategoryManager(
        categoryStore: categoryStore,
        timeBlockStore: timeBlockStore,
      );

      await manager.deleteCategory(42, keepRecords: true);

      expect(categoryStore.retiredIds, [42]);
      expect(categoryStore.deletedWithRecordsIds, isEmpty);
    });

    test('keepRecords: false → only deleteWithRecords() called', () async {
      final categoryStore = _FakeCategoryStore(db);
      final timeBlockStore = TimeBlockStore(db);
      final manager = CategoryManager(
        categoryStore: categoryStore,
        timeBlockStore: timeBlockStore,
      );

      await manager.deleteCategory(7, keepRecords: false);

      expect(categoryStore.deletedWithRecordsIds, [7]);
      expect(categoryStore.retiredIds, isEmpty);
    });
  });
}
