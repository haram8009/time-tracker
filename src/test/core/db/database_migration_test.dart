// ignore_for_file: depend_on_referenced_packages
//
// Verifies the v2 -> v3 sync-metadata migration (issue #90): existing rows
// survive, gain sync metadata, and new rows carry it too.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/sync_metadata.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';

/// Builds a pre-sync (v2) database: has isHidden but no sync columns.
Future<Database> _openLegacyV2Db() =>
    databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE categories (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                name     TEXT    NOT NULL,
                colorHex TEXT    NOT NULL,
                isPreset INTEGER NOT NULL DEFAULT 0,
                isHidden INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE time_blocks (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                date        TEXT    NOT NULL,
                startMinute INTEGER NOT NULL,
                endMinute   INTEGER NOT NULL,
                categoryId  INTEGER NOT NULL,
                note        TEXT,
                FOREIGN KEY(categoryId) REFERENCES categories(id)
              )
            ''');
          },
        ));

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('v2 -> v3 sync-metadata migration', () {
    late Database db;

    setUp(() async {
      db = await _openLegacyV2Db();
    });

    tearDown(() async => db.close());

    test('existing categories and time_blocks survive and gain metadata',
        () async {
      final catId = await db.insert('categories', {
        'name': '업무',
        'colorHex': '#EF5350',
        'isPreset': 1,
        'isHidden': 0,
      });
      await db.insert('time_blocks', {
        'date': '2026-01-01',
        'startMinute': 0,
        'endMinute': 10,
        'categoryId': catId,
        'note': 'legacy',
      });

      await migrateSchema(db, 2, appDatabaseVersion);

      final cat = (await db.query('categories')).single;
      expect(cat['name'], '업무');
      expect(cat['remoteId'], isNull);
      expect(cat['ownerId'], isNull);
      expect(cat['deletedAt'], isNull);
      expect(cat['syncStatus'], SyncColumns.pending);
      expect((cat['updatedAt'] as String).isNotEmpty, isTrue);

      final block = (await db.query('time_blocks')).single;
      expect(block['note'], 'legacy');
      expect(block['syncStatus'], SyncColumns.pending);
      expect((block['updatedAt'] as String).isNotEmpty, isTrue);
    });

    test('store writes on the migrated db mark rows pending', () async {
      await migrateSchema(db, 2, appDatabaseVersion);

      final catStore = CategoryStore(db, seedCategories: const []);
      final cat = await catStore.insert(
        const Category(name: '운동', colorHex: '#66BB6A'),
      );
      final blockStore = TimeBlockStore(db);
      await blockStore.insert(TimeBlock(
        date: const DateKey(2026, 1, 2),
        startMinute: 60,
        endMinute: 70,
        categoryId: cat.id!,
      ));

      final catRow = (await db.query('categories',
              where: 'id = ?', whereArgs: [cat.id]))
          .single;
      expect(catRow['syncStatus'], SyncColumns.pending);
      expect((catRow['updatedAt'] as String).isNotEmpty, isTrue);

      final blockRow = (await db.query('time_blocks')).single;
      expect(blockRow['syncStatus'], SyncColumns.pending);
      expect((blockRow['updatedAt'] as String).isNotEmpty, isTrue);
    });

    test('retire keeps the row and stamps it pending', () async {
      await migrateSchema(db, 2, appDatabaseVersion);
      final store = CategoryStore(db, seedCategories: const []);
      final cat = await store.insert(
        const Category(name: '임시', colorHex: '#123456'),
      );

      await store.retire(cat.id!);

      final row =
          (await db.query('categories', where: 'id = ?', whereArgs: [cat.id]))
              .single;
      expect(row['isHidden'], 1);
      expect(row['deletedAt'], isNull);
      expect(row['syncStatus'], SyncColumns.pending);
    });
  });
}
