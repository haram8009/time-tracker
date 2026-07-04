// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/sync_local_store.dart';
import 'package:time_tracker/core/db/sync_metadata.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/notifications/notification_settings.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/sync/cloud_pull_service.dart';
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

  @override
  Future<void> upsertCategory(RemoteCategory category) async =>
      categories[category.id] = category;

  @override
  Future<void> upsertTimeBlock(RemoteTimeBlock block) async =>
      blocks[block.id] = block;

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

const owner = 'owner-123';
const stamp = '2026-07-01T00:00:00.000Z';

RemoteCategory _cat(
  String id,
  String name, {
  bool isPreset = false,
  bool isHidden = false,
  int sortOrder = 0,
  String? deletedAt,
}) =>
    RemoteCategory(
      id: id,
      ownerId: owner,
      name: name,
      colorHex: '#EF5350',
      isPreset: isPreset,
      isHidden: isHidden,
      sortOrder: sortOrder,
      updatedAt: stamp,
      deletedAt: deletedAt,
    );

RemoteTimeBlock _block(
  String id,
  String categoryId, {
  String date = '2026-06-01',
  int start = 0,
  int end = 60,
  String? note,
  String? deletedAt,
}) =>
    RemoteTimeBlock(
      id: id,
      ownerId: owner,
      categoryId: categoryId,
      date: date,
      startMinute: start,
      endMinute: end,
      note: note,
      updatedAt: stamp,
      deletedAt: deletedAt,
    );

CloudPullService _service(_FakeCloud cloud, {PreferencesPort? prefs}) =>
    CloudPullService(
      local: SyncLocalStore(db),
      cloud: cloud,
      prefs: prefs ?? _FakePrefs(),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => db = await _openDb());
  tearDown(() async => db.close());

  test('fresh device pull rebuilds categories, blocks and settings', () async {
    final cloud = _FakeCloud();
    cloud.categories['cat-work'] = _cat('cat-work', '업무', sortOrder: 1);
    cloud.categories['cat-rest'] = _cat('cat-rest', '여가', sortOrder: 2);
    cloud.blocks['blk-1'] = _block('blk-1', 'cat-work', note: 'morning');
    cloud.blocks['blk-2'] = _block('blk-2', 'cat-rest', start: 60, end: 120);
    cloud.settings[owner] = const RemoteSettings(
      ownerId: owner,
      notificationEnabled: false,
      sleepStartMinute: 1320,
      sleepEndMinute: 360,
      updatedAt: stamp,
    );
    final prefs = _FakePrefs();

    await _service(cloud, prefs: prefs).pull(owner);

    // Categories landed with local ids + remote identity, synced.
    final cats = await db.query('categories', orderBy: 'id ASC');
    expect(cats.length, 2);
    expect(cats.every((r) => r['ownerId'] == owner), isTrue);
    expect(
        cats.every((r) => r['syncStatus'] == SyncColumns.synced), isTrue);
    final work = cats.singleWhere((r) => r['remoteId'] == 'cat-work');
    expect(work['name'], '업무');

    // Blocks reference the correct *local* category rows.
    final blocks = await db.query('time_blocks', orderBy: 'startMinute ASC');
    expect(blocks.length, 2);
    final morning = blocks.singleWhere((r) => r['note'] == 'morning');
    expect(morning['categoryId'], work['id']);
    expect(morning['remoteId'], 'blk-1');
    expect(morning['syncStatus'], SyncColumns.synced);

    // Settings landed in prefs.
    expect(prefs.getBool(NotificationSettings.keyEnabled), false);
    expect(prefs.getInt(NotificationSettings.keySleepStart), 1320);
    expect(prefs.getInt(NotificationSettings.keySleepEnd), 360);
  });

  test('retired category pulls hidden but usable for historical blocks',
      () async {
    final cloud = _FakeCloud();
    cloud.categories['cat-old'] = _cat('cat-old', '옛날', isHidden: true);
    cloud.blocks['blk-1'] = _block('blk-1', 'cat-old');

    await _service(cloud).pull(owner);

    final store = CategoryStore(db, seedCategories: const []);
    final visible = await store.fetchAll();
    expect(visible, isEmpty);
    final all = await store.fetchAllIncludingRetired();
    expect(all.single.name, '옛날');

    // Historical block still references the retired category's local row.
    final block = (await db.query('time_blocks')).single;
    expect(block['categoryId'], all.single.id);
  });

  test('second pull is idempotent (no duplicate local rows)', () async {
    final cloud = _FakeCloud();
    cloud.categories['cat-work'] = _cat('cat-work', '업무');
    cloud.blocks['blk-1'] = _block('blk-1', 'cat-work');

    final service = _service(cloud);
    await service.pull(owner);
    await service.pull(owner);

    expect((await db.query('categories')).length, 1);
    expect((await db.query('time_blocks')).length, 1);
  });

  test('remote preset adopts the local seeded preset by name', () async {
    final store = CategoryStore(db, seedCategories: const [
      Category(name: '수면', colorHex: '#5C6BC0', isPreset: true),
    ]);
    await store.seedIfNeeded();
    final seeded = (await db.query('categories')).single;

    final cloud = _FakeCloud();
    cloud.categories['cat-sleep'] =
        _cat('cat-sleep', '수면', isPreset: true);

    await _service(cloud).pull(owner);

    // No duplicate row — the seeded preset took over the remote identity.
    final cats = await db.query('categories');
    expect(cats.length, 1);
    expect(cats.single['id'], seeded['id']);
    expect(cats.single['remoteId'], 'cat-sleep');
    expect(cats.single['syncStatus'], SyncColumns.synced);
  });

  test('pending local edit wins over remote row until LWW (#94)', () async {
    final cloud = _FakeCloud();
    cloud.categories['cat-work'] = _cat('cat-work', '업무');
    final service = _service(cloud);
    await service.pull(owner);

    // Local rename not yet pushed.
    final localId = (await db.query('categories')).single['id'] as int;
    await db.update(
      'categories',
      {'name': '집중업무', 'syncStatus': SyncColumns.pending},
      where: 'id = ?',
      whereArgs: [localId],
    );

    await service.pull(owner);

    final row = (await db.query('categories')).single;
    expect(row['name'], '집중업무');
    expect(row['syncStatus'], SyncColumns.pending);
  });

  test('tombstoned remote rows and orphan blocks are skipped', () async {
    final cloud = _FakeCloud();
    cloud.categories['cat-dead'] =
        _cat('cat-dead', '삭제됨', deletedAt: stamp);
    cloud.categories['cat-live'] = _cat('cat-live', '업무');
    cloud.blocks['blk-dead'] = _block('blk-dead', 'cat-live', deletedAt: stamp);
    cloud.blocks['blk-orphan'] = _block('blk-orphan', 'cat-dead', start: 60, end: 120);
    cloud.blocks['blk-live'] = _block('blk-live', 'cat-live', start: 120, end: 180);

    await _service(cloud).pull(owner);

    final cats = await db.query('categories');
    expect(cats.single['remoteId'], 'cat-live');
    final blocks = await db.query('time_blocks');
    expect(blocks.single['remoteId'], 'blk-live');
  });

  test('empty cloud pulls nothing and leaves prefs untouched', () async {
    final prefs = _FakePrefs();

    await _service(_FakeCloud(), prefs: prefs).pull(owner);

    expect(await db.query('categories'), isEmpty);
    expect(await db.query('time_blocks'), isEmpty);
    expect(prefs.getBool(NotificationSettings.keyEnabled), isNull);
  });
}
