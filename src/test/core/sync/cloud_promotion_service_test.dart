// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/sync_local_store.dart';
import 'package:time_tracker/core/db/sync_metadata.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/sync/cloud_promotion_service.dart';
import 'package:time_tracker/core/sync/cloud_sync_port.dart';
import 'package:time_tracker/core/sync/remote_records.dart';

// ---------------------------------------------------------------------------
// Fakes
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

class _FakeCloud implements CloudSyncPort {
  final categories = <String, RemoteCategory>{};
  final blocks = <String, RemoteTimeBlock>{};
  final settings = <String, RemoteSettings>{};

  int categoryUpserts = 0;
  int blockUpserts = 0;

  /// If set, [upsertCategory] throws on the call whose (1-based) index matches.
  int? failCategoryOnCall;

  @override
  Future<void> upsertCategory(RemoteCategory category) async {
    categoryUpserts++;
    if (categoryUpserts == failCategoryOnCall) {
      throw StateError('injected failure');
    }
    categories[category.id] = category;
  }

  @override
  Future<void> upsertTimeBlock(RemoteTimeBlock block) async {
    blockUpserts++;
    blocks[block.id] = block;
  }

  @override
  Future<void> upsertSettings(RemoteSettings s) async =>
      settings[s.ownerId] = s;

  @override
  Future<List<RemoteCategory>> fetchCategories(String ownerId) async =>
      categories.values.where((c) => c.ownerId == ownerId).toList();

  @override
  Future<List<RemoteTimeBlock>> fetchTimeBlocks(String ownerId) async =>
      blocks.values.where((b) => b.ownerId == ownerId).toList();

  @override
  Future<RemoteSettings?> fetchSettings(String ownerId) async =>
      settings[ownerId];
}

// ---------------------------------------------------------------------------

late Database db;

Future<Database> _openDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: appDatabaseVersion,
        onCreate: (db, _) => createSchema(db),
      ),
    );

/// Deterministic id generator: uuid-1, uuid-2, ...
String Function() _counter() {
  var n = 0;
  return () => 'uuid-${++n}';
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => db = await _openDb());
  tearDown(() async => db.close());

  const owner = 'owner-123';

  test('promotes non-empty local data to owned cloud rows', () async {
    final catStore = CategoryStore(db, seedCategories: const []);
    final blockStore = TimeBlockStore(db);
    final work = await catStore.insert(
      const Category(name: '업무', colorHex: '#EF5350', isPreset: true),
    );
    final rest = await catStore.insert(
      const Category(name: '여가', colorHex: '#AB47BC'),
    );
    await blockStore.insert(TimeBlock(
      date: const DateKey(2026, 1, 1),
      startMinute: 0,
      endMinute: 60,
      categoryId: work.id!,
      note: 'morning',
    ));
    await blockStore.insert(TimeBlock(
      date: const DateKey(2026, 1, 1),
      startMinute: 60,
      endMinute: 120,
      categoryId: rest.id!,
    ));

    final cloud = _FakeCloud();
    final service = CloudPromotionService(
      local: SyncLocalStore(db),
      cloud: cloud,
      prefs: _FakePrefs(),
      newId: _counter(),
    );

    await service.promote(owner);

    // Cloud received both categories and both blocks, owner-stamped.
    expect(cloud.categories.length, 2);
    expect(cloud.blocks.length, 2);
    expect(cloud.categories.values.every((c) => c.ownerId == owner), isTrue);
    expect(cloud.settings.containsKey(owner), isTrue);

    // Block's remote category_id resolves to the promoted category's uuid.
    final workRemote = (await db.query('categories',
            columns: ['remoteId'], where: 'id = ?', whereArgs: [work.id]))
        .single['remoteId'];
    final morning =
        cloud.blocks.values.firstWhere((b) => b.note == 'morning');
    expect(morning.categoryId, workRemote);

    // Local rows now carry remote identity + synced status.
    final localCats = await db.query('categories');
    expect(localCats.every((r) => r['remoteId'] != null), isTrue);
    expect(
      localCats.every((r) => r['syncStatus'] == SyncColumns.synced),
      isTrue,
    );
    expect(
      localCats.every((r) => r['ownerId'] == owner),
      isTrue,
    );
  });

  test('empty local data promotes only settings, no crash', () async {
    final cloud = _FakeCloud();
    final service = CloudPromotionService(
      local: SyncLocalStore(db),
      cloud: cloud,
      prefs: _FakePrefs(),
      newId: _counter(),
    );

    await service.promote(owner);

    expect(cloud.categories, isEmpty);
    expect(cloud.blocks, isEmpty);
    expect(cloud.settings.containsKey(owner), isTrue);
  });

  test('re-running promotion is idempotent (no duplicate remote rows)',
      () async {
    final catStore = CategoryStore(db, seedCategories: const []);
    await catStore.insert(const Category(name: 'A', colorHex: '#111111'));
    await catStore.insert(const Category(name: 'B', colorHex: '#222222'));

    final cloud = _FakeCloud();
    final service = CloudPromotionService(
      local: SyncLocalStore(db),
      cloud: cloud,
      prefs: _FakePrefs(),
      newId: _counter(),
    );

    await service.promote(owner);
    final afterFirst = cloud.categoryUpserts;

    await service.promote(owner);

    // Second run finds nothing pending → no extra category upserts, no dupes.
    expect(cloud.categoryUpserts, afterFirst);
    expect(cloud.categories.length, 2);
  });

  test('retry after partial failure reuses ids and avoids duplicates',
      () async {
    final catStore = CategoryStore(db, seedCategories: const []);
    await catStore.insert(const Category(name: 'A', colorHex: '#111111'));
    await catStore.insert(const Category(name: 'B', colorHex: '#222222'));
    await catStore.insert(const Category(name: 'C', colorHex: '#333333'));

    final cloud = _FakeCloud()..failCategoryOnCall = 2;
    final service = CloudPromotionService(
      local: SyncLocalStore(db),
      cloud: cloud,
      prefs: _FakePrefs(),
      newId: _counter(),
    );

    // First attempt blows up on the 2nd category.
    await expectLater(service.promote(owner), throwsStateError);

    // One category synced, the failing one is pending but already has a
    // remote id assigned.
    final synced = await db.query('categories',
        where: 'syncStatus = ?', whereArgs: [SyncColumns.synced]);
    expect(synced.length, 1);
    final pendingWithId = await db.query('categories',
        where: 'syncStatus = ? AND remoteId IS NOT NULL',
        whereArgs: [SyncColumns.pending]);
    expect(pendingWithId.length, 1);

    // Retry succeeds and does not create duplicate remote rows.
    cloud.failCategoryOnCall = null;
    await service.promote(owner);

    expect(cloud.categories.length, 3);
    final allSynced = await db.query('categories',
        where: 'syncStatus = ?', whereArgs: [SyncColumns.synced]);
    expect(allSynced.length, 3);
    // Distinct remote ids for all three categories.
    final remoteIds =
        (await db.query('categories', columns: ['remoteId']))
            .map((r) => r['remoteId'])
            .toSet();
    expect(remoteIds.length, 3);
  });
}
