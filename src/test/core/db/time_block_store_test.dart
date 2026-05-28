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

    test('countByCategory returns 0 for category with no blocks', () async {
      final store = TimeBlockStore();
      expect(await store.countByCategory(1), 0);
    });

    test('countByCategory counts only blocks for that category', () async {
      final store = TimeBlockStore();
      final db = await DatabaseHelper.instance.database;
      await db.insert('categories',
          {'name': 'Other', 'colorHex': '#FFFFFF', 'isPreset': 0});

      await store.insert(const TimeBlock(
        date: '2026-01-01', startMinute: 0, endMinute: 10, categoryId: 1,
      ));
      await store.insert(const TimeBlock(
        date: '2026-01-01', startMinute: 10, endMinute: 20, categoryId: 1,
      ));
      await store.insert(const TimeBlock(
        date: '2026-01-01', startMinute: 20, endMinute: 30, categoryId: 2,
      ));

      expect(await store.countByCategory(1), 2);
      expect(await store.countByCategory(2), 1);
    });

    test('mergeOrInsert – no adjacent blocks: plain insert', () async {
      final store = TimeBlockStore();
      final result = await store.mergeOrInsert(const TimeBlock(
        date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
      ));
      expect(result.id, isNotNull);
      final all = await store.fetchByDate('2026-05-27');
      expect(all.length, 1);
      expect(all.first.startMinute, 100);
      expect(all.first.endMinute, 110);
    });

    test('mergeOrInsert – prev adjacent same category: extends prev', () async {
      final store = TimeBlockStore();
      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 80, endMinute: 100, categoryId: 1,
      ));
      await store.mergeOrInsert(const TimeBlock(
        date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
      ));
      final all = await store.fetchByDate('2026-05-27');
      expect(all.length, 1);
      expect(all.first.startMinute, 80);
      expect(all.first.endMinute, 110);
    });

    test('mergeOrInsert – next adjacent same category: extends next', () async {
      final store = TimeBlockStore();
      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 110, endMinute: 130, categoryId: 1,
      ));
      await store.mergeOrInsert(const TimeBlock(
        date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
      ));
      final all = await store.fetchByDate('2026-05-27');
      expect(all.length, 1);
      expect(all.first.startMinute, 100);
      expect(all.first.endMinute, 130);
    });

    test('mergeOrInsert – both adjacent same category: merges three into one', () async {
      final store = TimeBlockStore();
      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 80, endMinute: 100, categoryId: 1,
      ));
      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 110, endMinute: 130, categoryId: 1,
      ));
      await store.mergeOrInsert(const TimeBlock(
        date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
      ));
      final all = await store.fetchByDate('2026-05-27');
      expect(all.length, 1);
      expect(all.first.startMinute, 80);
      expect(all.first.endMinute, 130);
    });

    test('mergeOrInsert – adjacent but different category: no merge', () async {
      final store = TimeBlockStore();
      // Insert a second category
      final db = await DatabaseHelper.instance.database;
      await db.insert('categories', {'name': 'Other', 'colorHex': '#FFFFFF', 'isPreset': 0});

      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 80, endMinute: 100, categoryId: 1,
      ));
      await store.mergeOrInsert(const TimeBlock(
        date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 2,
      ));
      final all = await store.fetchByDate('2026-05-27');
      expect(all.length, 2);
    });

    group('replaceRange', () {
      test('no overlap: plain insert', () async {
        final store = TimeBlockStore();
        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
        ));
        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 1);
        expect(all.first.startMinute, 100);
        expect(all.first.endMinute, 110);
      });

      test('fully covered block deleted', () async {
        final store = TimeBlockStore();
        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
        ));
        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 100, endMinute: 110, categoryId: 1,
        ));
        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 1);
        expect(all.first.startMinute, 100);
        expect(all.first.endMinute, 110);
      });

      test('케이스1: 재할당 셀과 인접 동일 카테고리 병합', () async {
        final store = TimeBlockStore();
        final db = await DatabaseHelper.instance.database;
        await db.insert('categories',
            {'name': 'Other', 'colorHex': '#FFFFFF', 'isPreset': 0});

        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 1,
        ));
        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 10, endMinute: 20, categoryId: 2,
        ));

        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 2,
        ));

        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 1);
        expect(all.first.startMinute, 0);
        expect(all.first.endMinute, 20);
        expect(all.first.categoryId, 2);
      });

      test('케이스2: 기존 블록 내부 범위 → split', () async {
        final store = TimeBlockStore();
        final db = await DatabaseHelper.instance.database;
        await db.insert('categories',
            {'name': 'Other', 'colorHex': '#FFFFFF', 'isPreset': 0});

        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 30, categoryId: 1,
        ));

        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 10, endMinute: 20, categoryId: 2,
        ));

        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 3);
        expect(all[0].startMinute, 0);
        expect(all[0].endMinute, 10);
        expect(all[0].categoryId, 1);
        expect(all[1].startMinute, 10);
        expect(all[1].endMinute, 20);
        expect(all[1].categoryId, 2);
        expect(all[2].startMinute, 20);
        expect(all[2].endMinute, 30);
        expect(all[2].categoryId, 1);
      });

      test('케이스3: 여러 블록 걸치는 범위 → 양쪽 trim + 중간 삭제', () async {
        final store = TimeBlockStore();
        final db = await DatabaseHelper.instance.database;
        await db.insert('categories',
            {'name': 'Cat2', 'colorHex': '#FFFFFF', 'isPreset': 0});
        await db.insert('categories',
            {'name': 'Cat3', 'colorHex': '#AAAAAA', 'isPreset': 0});

        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 20, categoryId: 1,
        ));
        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 20, endMinute: 40, categoryId: 2,
        ));

        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 10, endMinute: 30, categoryId: 3,
        ));

        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 3);
        expect(all[0].startMinute, 0);
        expect(all[0].endMinute, 10);
        expect(all[0].categoryId, 1);
        expect(all[1].startMinute, 10);
        expect(all[1].endMinute, 30);
        expect(all[1].categoryId, 3);
        expect(all[2].startMinute, 30);
        expect(all[2].endMinute, 40);
        expect(all[2].categoryId, 2);
      });

      test('양쪽 인접 동일 카테고리 → 3개 병합', () async {
        final store = TimeBlockStore();
        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 1,
        ));
        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 20, endMinute: 30, categoryId: 1,
        ));

        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 10, endMinute: 20, categoryId: 1,
        ));

        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 1);
        expect(all.first.startMinute, 0);
        expect(all.first.endMinute, 30);
        expect(all.first.categoryId, 1);
      });

      test('기존 블록 전체 덮는 범위로 재할당', () async {
        final store = TimeBlockStore();
        final db = await DatabaseHelper.instance.database;
        await db.insert('categories',
            {'name': 'Other', 'colorHex': '#FFFFFF', 'isPreset': 0});

        await store.insert(const TimeBlock(
          date: '2026-05-27', startMinute: 10, endMinute: 20, categoryId: 1,
        ));

        await store.replaceRange(const TimeBlock(
          date: '2026-05-27', startMinute: 0, endMinute: 30, categoryId: 2,
        ));

        final all = await store.fetchByDate('2026-05-27');
        expect(all.length, 1);
        expect(all.first.startMinute, 0);
        expect(all.first.endMinute, 30);
        expect(all.first.categoryId, 2);
      });
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

    test('changes emits on insert', () async {
      final store = TimeBlockStore();
      final future = store.changes.first;
      await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 1,
      ));
      await expectLater(future, completes);
    });

    test('changes emits on replaceRange', () async {
      final store = TimeBlockStore();
      final future = store.changes.first;
      await store.replaceRange(const TimeBlock(
        date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 1,
      ));
      await expectLater(future, completes);
    });

    test('changes emits on delete', () async {
      final store = TimeBlockStore();
      final inserted = await store.insert(const TimeBlock(
        date: '2026-05-27', startMinute: 0, endMinute: 10, categoryId: 1,
      ));
      final future = store.changes.first;
      await store.delete(inserted.id!);
      await expectLater(future, completes);
    });
  });
}
