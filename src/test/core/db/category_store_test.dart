// ignore_for_file: depend_on_referenced_packages
//
// NOTE: These tests require the following dev dependency:
//   sqflite_common_ffi: ^2.3.4
// Add it to pubspec.yaml under dev_dependencies and run `flutter pub get`.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/services/preferences_port.dart';

// ---------------------------------------------------------------------------
// Fake PreferencesPort for testing
// ---------------------------------------------------------------------------

class _FakePrefs implements PreferencesPort {
  final _bools = <String, bool>{};
  final _ints = <String, int>{};

  @override
  bool? getBool(String key) => _bools[key];

  @override
  int? getInt(String key) => _ints[key];

  @override
  Future<void> setBool(String key, bool value) async => _bools[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _ints[key] = value;
}

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() => DatabaseHelper.resetForTesting());

  setUp(() async {
    await DatabaseHelper.resetForTesting();
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
      ),
    );
    DatabaseHelper.setDatabaseForTesting(db);
  });

  group('CategoryStore – preset seeding', () {
    test('seedIfNeeded inserts 6 preset categories on first run', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final all = await store.fetchAll();
      expect(all.length, 6);
      expect(all.every((c) => c.isPreset), isTrue);
    });

    test('seedIfNeeded is idempotent – calling twice does not duplicate presets',
        () async {
      final store = CategoryStore();
      await store.seedIfNeeded();
      await store.seedIfNeeded();

      final all = await store.fetchAll();
      expect(all.length, 6);
    });

    test('preset names match specification', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final names = (await store.fetchAll()).map((c) => c.name).toSet();
      expect(names, containsAll(['수면', '업무', '운동', '식사', '이동', '여가']));
    });

    test('preset color hex values match specification', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final byName = {
        for (final c in await store.fetchAll()) c.name: c.colorHex
      };
      expect(byName['수면'], '#5C6BC0');
      expect(byName['업무'], '#EF5350');
      expect(byName['운동'], '#66BB6A');
      expect(byName['식사'], '#FFA726');
      expect(byName['이동'], '#26C6DA');
      expect(byName['여가'], '#AB47BC');
    });

    test('prefs flag prevents re-seeding on subsequent launches', () async {
      final prefs = _FakePrefs();

      // First store instance: seeds and sets flag.
      final store1 = CategoryStore(seedCategories: const [], prefs: prefs);
      await store1.seedIfNeeded();
      expect((await store1.fetchAll()), isEmpty);

      // Simulate re-launch: new store with same prefs (flag already set).
      // Even if DB is empty, seeding is skipped.
      final store2 = CategoryStore(prefs: prefs);
      final all = await store2.fetchAll();
      expect(all, isEmpty);
    });
  });

  group('CategoryStore – custom seed injection', () {
    test('custom seedCategories replaces default presets', () async {
      const custom = [
        Category(name: '테스트A', colorHex: '#111111', isPreset: true),
        Category(name: '테스트B', colorHex: '#222222', isPreset: true),
      ];
      final store = CategoryStore(seedCategories: custom);
      final all = await store.fetchAll();
      expect(all.length, 2);
      expect(all.map((c) => c.name).toList(), ['테스트A', '테스트B']);
    });

    test('empty seedCategories seeds nothing', () async {
      final store = CategoryStore(seedCategories: const []);
      final all = await store.fetchAll();
      expect(all, isEmpty);
    });

    test('auto-init: fetchAll works without explicit seedIfNeeded()', () async {
      final store = CategoryStore();
      final all = await store.fetchAll();
      expect(all.length, 6);
    });

    test('auto-init: watchAll emits without explicit seedIfNeeded()', () async {
      final store = CategoryStore();
      final list = await store.watchAll().first;
      expect(list.length, 6);
      store.dispose();
    });
  });

  group('CategoryStore – CRUD', () {
    test('insert adds a new category and returns it with an id', () async {
      final store = CategoryStore();
      const category = Category(name: '독서', colorHex: '#FFFFFF');

      final inserted = await store.insert(category);

      expect(inserted.id, isNotNull);
      expect(inserted.name, '독서');
      expect(inserted.colorHex, '#FFFFFF');
      expect(inserted.isPreset, isFalse);
    });

    test('fetchAll returns all categories including newly inserted', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();
      await store.insert(const Category(name: '독서', colorHex: '#FFFFFF'));

      final all = await store.fetchAll();
      expect(all.length, 7);
    });

    test('update modifies an existing category', () async {
      final store = CategoryStore();
      final inserted = await store.insert(
        const Category(name: '독서', colorHex: '#FFFFFF'),
      );

      final updated = inserted.copyWith(name: '독서/공부', colorHex: '#EEEEEE');
      await store.update(updated);

      final all = await store.fetchAll();
      final found = all.firstWhere((c) => c.id == inserted.id);
      expect(found.name, '독서/공부');
      expect(found.colorHex, '#EEEEEE');
    });

    test('update works on preset categories', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final preset = (await store.fetchAll()).first;
      await store.update(preset.copyWith(name: '수정된이름', colorHex: '#000000'));

      final found = (await store.fetchAll()).firstWhere((c) => c.id == preset.id);
      expect(found.name, '수정된이름');
      expect(found.colorHex, '#000000');
      expect(found.isPreset, isTrue);
    });

    test('delete soft-hides category — not visible in fetchAll', () async {
      final store = CategoryStore();
      final inserted = await store.insert(
        const Category(name: '임시', colorHex: '#123456'),
      );

      await store.delete(inserted.id!);

      final all = await store.fetchAll();
      expect(all.any((c) => c.id == inserted.id), isFalse);
    });

    test('delete soft-hides preset — not visible in fetchAll', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final preset = (await store.fetchAll()).first;
      await store.delete(preset.id!);

      final all = await store.fetchAll();
      expect(all.any((c) => c.id == preset.id), isFalse);
      expect(all.length, 5);
    });

    test('watchAll emits current snapshot immediately', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final stream = store.watchAll();
      final list = await stream.first;
      expect(list.length, 6);
    });

    test('watchAll emits updated list after insert', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final events = <List<Category>>[];
      final sub = store.watchAll().listen(events.add);

      // Wait for the initial snapshot
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await store.insert(const Category(name: '새카테고리', colorHex: '#AAAAAA'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events.length, greaterThanOrEqualTo(2));
      expect(events.last.length, 7);

      await sub.cancel();
      store.dispose();
    });
  });

  group('CategoryStore – restoreDefaults', () {
    test('restoreDefaults makes hidden presets visible again', () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final presets = await store.fetchAll();
      for (final p in presets) {
        await store.delete(p.id!);
      }
      expect(await store.fetchAll(), isEmpty);

      await store.restoreDefaults();

      final restored = await store.fetchAll();
      expect(restored.length, 6);
      expect(restored.every((c) => c.isPreset), isTrue);
    });

    test('restoreDefaults does not affect user-defined hidden categories',
        () async {
      final store = CategoryStore();
      await store.seedIfNeeded();

      final user = await store.insert(
        const Category(name: '사용자카테고리', colorHex: '#ABCDEF'),
      );
      await store.delete(user.id!);

      await store.restoreDefaults();

      final all = await store.fetchAll();
      expect(all.any((c) => c.id == user.id), isFalse);
      expect(all.length, 6);
    });
  });
}
