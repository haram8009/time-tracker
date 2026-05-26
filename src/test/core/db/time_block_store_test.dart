// ignore_for_file: depend_on_referenced_packages
//
// NOTE: These tests require the following dev dependency:
//   sqflite_common_ffi: ^2.3.4
// Add it to pubspec.yaml under dev_dependencies and run `flutter pub get`.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/time_block.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() => DatabaseHelper.resetForTesting());

  setUp(() async {
    await DatabaseHelper.resetForTesting();
    // Each test gets a fresh in-memory database.
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE categories (
              id       INTEGER PRIMARY KEY AUTOINCREMENT,
              name     TEXT    NOT NULL,
              colorHex TEXT    NOT NULL,
              isPreset INTEGER NOT NULL DEFAULT 0
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
          // Insert a dummy category so foreign-key inserts succeed.
          await db.insert('categories', {
            'name': 'Test',
            'colorHex': '#000000',
            'isPreset': 0,
          });
        },
      ),
    );
    DatabaseHelper.setDatabaseForTesting(db);
  });

  group('TimeBlockStore', () {
    test('insert and fetchByDate returns the inserted block', () async {
      final store = TimeBlockStore();
      const block = TimeBlock(
        date: '2026-05-27',
        startMinute: 480,
        endMinute: 540,
        categoryId: 1,
        note: 'morning work',
      );

      final inserted = await store.insert(block);

      expect(inserted.id, isNotNull);
      expect(inserted.date, '2026-05-27');
      expect(inserted.startMinute, 480);
      expect(inserted.endMinute, 540);
      expect(inserted.note, 'morning work');

      final list = await store.fetchByDate('2026-05-27');
      expect(list.length, 1);
      expect(list.first.id, inserted.id);
    });

    test('fetchByDate returns empty list for a date with no blocks', () async {
      final store = TimeBlockStore();
      final list = await store.fetchByDate('2000-01-01');
      expect(list, isEmpty);
    });

    test('update modifies an existing block', () async {
      final store = TimeBlockStore();
      final inserted = await store.insert(
        const TimeBlock(
          date: '2026-05-27',
          startMinute: 60,
          endMinute: 120,
          categoryId: 1,
        ),
      );

      final updated = inserted.copyWith(endMinute: 180, note: 'updated');
      await store.update(updated);

      final list = await store.fetchByDate('2026-05-27');
      expect(list.length, 1);
      expect(list.first.endMinute, 180);
      expect(list.first.note, 'updated');
    });

    test('delete removes the block', () async {
      final store = TimeBlockStore();
      final inserted = await store.insert(
        const TimeBlock(
          date: '2026-05-27',
          startMinute: 200,
          endMinute: 260,
          categoryId: 1,
        ),
      );

      await store.delete(inserted.id!);

      final list = await store.fetchByDate('2026-05-27');
      expect(list, isEmpty);
    });

    test('insert multiple blocks and fetch returns all sorted by startMinute',
        () async {
      final store = TimeBlockStore();
      await store.insert(
        const TimeBlock(
          date: '2026-05-27',
          startMinute: 600,
          endMinute: 660,
          categoryId: 1,
        ),
      );
      await store.insert(
        const TimeBlock(
          date: '2026-05-27',
          startMinute: 120,
          endMinute: 180,
          categoryId: 1,
        ),
      );

      final list = await store.fetchByDate('2026-05-27');
      expect(list.length, 2);
      expect(list[0].startMinute, 120);
      expect(list[1].startMinute, 600);
    });

    test('watchByDate emits current snapshot immediately', () async {
      final store = TimeBlockStore();
      await store.insert(
        const TimeBlock(
          date: '2026-05-27',
          startMinute: 300,
          endMinute: 360,
          categoryId: 1,
        ),
      );

      final stream = store.watchByDate('2026-05-27');
      final list = await stream.first;
      expect(list.length, 1);
    });
  });
}
