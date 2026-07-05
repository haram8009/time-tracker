// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/auth/auth_account.dart';
import 'package:time_tracker/core/auth/auth_port.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/sync_local_store.dart';
import 'package:time_tracker/core/db/sync_metadata.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_settings.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/sync/cloud_promotion_service.dart';
import 'package:time_tracker/core/sync/cloud_pull_service.dart';
import 'package:time_tracker/core/sync/cloud_sync_port.dart';
import 'package:time_tracker/core/sync/remote_records.dart';
import 'package:time_tracker/core/sync/sync_service.dart';

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

  int blockUpserts = 0;

  /// When true, every write throws (simulated network/remote failure).
  bool failWrites = false;

  void _checkWrite() {
    if (failWrites) throw StateError('injected write failure');
  }

  @override
  Future<void> upsertCategory(RemoteCategory category) async {
    _checkWrite();
    categories[category.id] = category;
  }

  @override
  Future<void> upsertTimeBlock(RemoteTimeBlock block) async {
    _checkWrite();
    blockUpserts++;
    blocks[block.id] = block;
  }

  @override
  Future<void> upsertSettings(RemoteSettings s) async {
    _checkWrite();
    settings[s.ownerId] = s;
  }

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

class _FakeAuth implements AuthPort {
  @override
  AuthAccount? currentAccount;

  @override
  Stream<AuthAccount?> authChanges() => const Stream.empty();
  @override
  Future<AuthAccount?> signInWithGoogle() async => currentAccount;
  @override
  Future<void> signOut() async => currentAccount = null;
}

// ---------------------------------------------------------------------------
// A simulated device: its own SQLite db + prefs + stores + sync service, all
// sharing one fake cloud. Mirrors the real wiring in main.dart.
// ---------------------------------------------------------------------------

const owner = 'owner-123';

class _Device {
  late final Database db;
  final prefs = _FakePrefs();
  final auth = _FakeAuth()..currentAccount = const AuthAccount(id: owner);
  late final CategoryStore categories;
  late final TimeBlockStore blocks;
  late final SyncService sync;
  late final SyncService freshSync;
  int settingsReloads = 0;

  static int _uuidCounter = 0;

  static Future<_Device> boot() async {
    final d = _Device();
    d.db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: appDatabaseVersion,
        onCreate: (db, _) => createSchema(db),
        // Both devices open the same in-memory path; without this they would
        // silently share one database instance.
        singleInstance: false,
      ),
    );
    d.categories = CategoryStore(d.db, seedCategories: const []);
    d.blocks = TimeBlockStore(d.db);
    return d;
  }

  void connect(_FakeCloud cloud) => sync = _buildSync(cloud);

  /// Second service over the same db/prefs — simulates an app relaunch.
  void connectFresh(_FakeCloud cloud) => freshSync = _buildSync(cloud);

  SyncService _buildSync(_FakeCloud cloud) {
    final local = SyncLocalStore(db);
    return SyncService(
      pull: CloudPullService(local: local, cloud: cloud, prefs: prefs),
      promote: CloudPromotionService(
        local: local,
        cloud: cloud,
        prefs: prefs,
        newId: () => 'uuid-${++_uuidCounter}',
      ),
      local: local,
      prefs: prefs,
      auth: auth,
      categories: categories,
      blocks: blocks,
      reloadSettings: () async => settingsReloads++,
      debounce: Duration.zero,
    );
  }

  Future<void> close() => db.close();
}

TimeBlock _block(int categoryId, {int start = 0, int end = 60, String? note}) =>
    TimeBlock(
      date: const DateKey(2026, 7, 1),
      startMinute: start,
      endMinute: end,
      categoryId: categoryId,
      note: note,
    );

/// Backdates/postdates a row's LWW stamp for deterministic conflicts.
Future<void> _setUpdatedAt(
  Database db,
  String table,
  int id,
  String iso, {
  Map<String, Object?> also = const {},
}) =>
    db.update(table, {SyncColumns.updatedAt: iso, ...also},
        where: 'id = ?', whereArgs: [id]);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late _FakeCloud cloud;
  late _Device a;
  late _Device b;

  setUp(() async {
    cloud = _FakeCloud();
    a = await _Device.boot();
    b = await _Device.boot();
    a.connect(cloud);
    b.connect(cloud);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('pending local edits upload during sync (incremental push)', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.sync.sync(owner);
    expect(cloud.categories.length, 1);

    // Post-promotion edit + new block are pending, next sync pushes them.
    await a.categories.update(cat.copyWith(name: '집중업무'));
    await a.blocks.insert(_block(cat.id!, note: 'work'));

    await a.sync.sync(owner);

    expect(cloud.categories.values.single.name, '집중업무');
    expect(cloud.blocks.values.single.note, 'work');
    final rows = await a.db.query('categories');
    expect(rows.single['syncStatus'], SyncColumns.synced);
  });

  test('remote newer rows update local rows during sync', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.blocks.insert(_block(cat.id!, note: 'v1'));
    await a.sync.sync(owner);
    await b.sync.sync(owner);
    expect((await b.blocks.fetchByDate(const DateKey(2026, 7, 1))).single.note,
        'v1');

    // A edits and pushes; B pulls the newer row.
    final blockA =
        (await a.blocks.fetchByDate(const DateKey(2026, 7, 1))).single;
    await a.blocks.update(blockA.copyWith(note: 'v2'));
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    expect((await b.blocks.fetchByDate(const DateKey(2026, 7, 1))).single.note,
        'v2');
  });

  test('local delete tombstones synced rows and propagates; unsynced rows '
      'hard-delete without touching the cloud', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    final syncedBlock = await a.blocks.insert(_block(cat.id!));
    await a.sync.sync(owner);
    final unsyncedBlock = await a.blocks.insert(_block(cat.id!, start: 60, end: 120));
    final upsertsBefore = cloud.blockUpserts;

    await a.blocks.delete(unsyncedBlock.id!);
    await a.blocks.delete(syncedBlock.id!);

    // Unsynced row is gone outright; synced row is a pending tombstone.
    final rows = await a.db.query('time_blocks');
    expect(rows.length, 1);
    expect(rows.single[SyncColumns.deletedAt], isNotNull);
    expect(rows.single['syncStatus'], SyncColumns.pending);
    // Reads exclude tombstones.
    expect(await a.blocks.fetchByDate(const DateKey(2026, 7, 1)), isEmpty);
    expect(await a.blocks.countByCategory(cat.id!), 0);

    await a.sync.sync(owner);

    // Only the tombstone was pushed; the unsynced row never reached the cloud.
    expect(cloud.blockUpserts, upsertsBefore + 1);
    expect(cloud.blocks.values.single.deletedAt, isNotNull);
  });

  test('remote deletes propagate without resurrecting rows', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.blocks.insert(_block(cat.id!));
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    final blockB =
        (await b.blocks.fetchByDate(const DateKey(2026, 7, 1))).single;
    await b.blocks.delete(blockB.id!);
    await b.sync.sync(owner);

    // A pulls the tombstone; repeated syncs on both sides never resurrect it.
    await a.sync.sync(owner);
    expect(await a.blocks.fetchByDate(const DateKey(2026, 7, 1)), isEmpty);
    await a.sync.sync(owner);
    await b.sync.sync(owner);
    expect(await a.blocks.fetchByDate(const DateKey(2026, 7, 1)), isEmpty);
    expect(await b.blocks.fetchByDate(const DateKey(2026, 7, 1)), isEmpty);
    expect(cloud.blocks.values.single.deletedAt, isNotNull);
  });

  test('deleteWithRecords tombstones the category and its blocks across '
      'devices', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.blocks.insert(_block(cat.id!));
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    await a.categories.deleteWithRecords(cat.id!);
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    expect(cloud.categories.values.single.deletedAt, isNotNull);
    expect(cloud.blocks.values.single.deletedAt, isNotNull);
    expect(await b.categories.fetchAllIncludingRetired(), isEmpty);
    expect(await b.blocks.fetchByDate(const DateKey(2026, 7, 1)), isEmpty);
  });

  test('concurrent edits resolve by latest updatedAt (LWW)', () async {
    await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    // Both devices edit the same category offline; B's edit is later.
    final idA = (await a.db.query('categories')).single['id'] as int;
    final idB = (await b.db.query('categories')).single['id'] as int;
    await _setUpdatedAt(a.db, 'categories', idA, '2027-07-02T00:00:00.000Z',
        also: {'name': 'A안', 'syncStatus': SyncColumns.pending});
    await _setUpdatedAt(b.db, 'categories', idB, '2027-07-03T00:00:00.000Z',
        also: {'name': 'B안', 'syncStatus': SyncColumns.pending});

    // A syncs first, then B (B's pull keeps its newer local edit, then pushes).
    await a.sync.sync(owner);
    await b.sync.sync(owner);
    await a.sync.sync(owner);

    expect(cloud.categories.values.single.name, 'B안');
    expect((await a.db.query('categories')).single['name'], 'B안');
    expect((await b.db.query('categories')).single['name'], 'B안');
  });

  test('newer remote live edit wins over older local tombstone (LWW '
      'resurrection)', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    final block = await a.blocks.insert(_block(cat.id!, note: 'keep me'));
    await a.sync.sync(owner);
    await b.sync.sync(owner);

    // A deletes (older stamp), B edits the same block later.
    await a.blocks.delete(block.id!);
    final idA = (await a.db.query('time_blocks')).single['id'] as int;
    await _setUpdatedAt(a.db, 'time_blocks', idA, '2027-07-02T00:00:00.000Z');
    final blockB =
        (await b.blocks.fetchByDate(const DateKey(2026, 7, 1))).single;
    await b.blocks.update(blockB.copyWith(note: 'edited later'));
    final idB = (await b.db.query('time_blocks')).single['id'] as int;
    await _setUpdatedAt(b.db, 'time_blocks', idB, '2027-07-03T00:00:00.000Z');

    await a.sync.sync(owner); // pushes tombstone
    await b.sync.sync(owner); // pulls tombstone, local edit newer → wins, pushes
    await a.sync.sync(owner); // pulls the resurrected row

    expect(cloud.blocks.values.single.deletedAt, isNull);
    expect((await a.blocks.fetchByDate(const DateKey(2026, 7, 1))).single.note,
        'edited later');
  });

  test('settings sync: pending edit uploads, newer remote wins, older remote '
      'does not clobber', () async {
    // A edits settings locally, then syncs → cloud has A's values.
    final settingsA = _FakeSettingsEditor(a.prefs);
    await settingsA.setEnabled(false, atMillis: 1000);
    await a.sync.sync(owner);
    expect(cloud.settings[owner]!.notificationEnabled, false);

    // B (fresh, no local stamp) pulls A's settings.
    await b.sync.sync(owner);
    expect(b.prefs.getBool(NotificationSettings.keyEnabled), false);
    expect(b.prefs.getBool(SettingsSyncKeys.dirty), false);

    // B edits later → pushes; A pulls the newer value.
    final settingsB = _FakeSettingsEditor(b.prefs);
    await settingsB.setEnabled(true, atMillis: 2000);
    await b.sync.sync(owner);
    await a.sync.sync(owner);
    expect(a.prefs.getBool(NotificationSettings.keyEnabled), true);

    // A now edits later still; pulling the older remote must not clobber it.
    await settingsA.setEnabled(false, atMillis: 3000);
    await a.sync.sync(owner);
    expect(cloud.settings[owner]!.notificationEnabled, false);
    expect(a.prefs.getBool(NotificationSettings.keyEnabled), false);
  });

  test('sync stays retry-safe after remote write failure', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.blocks.insert(_block(cat.id!));

    cloud.failWrites = true;
    await a.sync.sync(owner); // swallowed failure

    // Everything still pending locally; local tracking unaffected.
    final pendingCats = await a.db.query('categories',
        where: 'syncStatus = ?', whereArgs: [SyncColumns.pending]);
    expect(pendingCats.length, 1);
    expect(cloud.categories, isEmpty);

    cloud.failWrites = false;
    await a.sync.sync(owner);

    expect(cloud.categories.length, 1);
    expect(cloud.blocks.length, 1);
    final rows = await a.db.query('categories');
    expect(rows.single['syncStatus'], SyncColumns.synced);
  });

  test('store mutations trigger a debounced auto-sync when signed in', () async {
    a.sync.start();
    await a.categories.insert(const Category(name: '업무', colorHex: '#EF5350'));

    // Let the zero-debounce timer and the sync run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(cloud.categories.length, 1);
    expect((await a.db.query('categories')).single['syncStatus'],
        SyncColumns.synced);
    a.sync.dispose();
  });

  test('status transitions: syncing → idle with persisted lastSyncedAt on '
      'success', () async {
    expect(a.sync.state.phase, SyncPhase.idle);
    expect(a.sync.state.lastSyncedAt, isNull);

    final phases = <SyncPhase>[];
    a.sync.addListener((s) => phases.add(s.phase), fireImmediately: false);

    await a.categories.insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.sync.sync(owner);

    expect(phases, [SyncPhase.syncing, SyncPhase.idle]);
    expect(a.sync.state.lastSyncedAt, isNotNull);
    expect(a.sync.state.error, isNull);
    expect(a.prefs.getInt(SyncService.lastSyncMillisKey),
        a.sync.state.lastSyncedAt!.millisecondsSinceEpoch);
  });

  test('status transitions: failure → error state, lastSyncedAt kept, local '
      'edits unaffected', () async {
    final cat = await a.categories
        .insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.sync.sync(owner);
    final lastSuccess = a.sync.state.lastSyncedAt;

    cloud.failWrites = true;
    await a.blocks.insert(_block(cat.id!));
    await a.sync.sync(owner);

    expect(a.sync.state.phase, SyncPhase.error);
    expect(a.sync.state.error, isNotNull);
    expect(a.sync.state.lastSyncedAt, lastSuccess);

    // Failed sync never blocks local tracking.
    await a.blocks.insert(_block(cat.id!, start: 60, end: 120));
    expect(
        (await a.blocks.fetchByDate(const DateKey(2026, 7, 1))).length, 2);

    // Recovery: next successful sync clears the error.
    cloud.failWrites = false;
    await a.sync.sync(owner);
    expect(a.sync.state.phase, SyncPhase.idle);
    expect(a.sync.state.error, isNull);
    expect(a.sync.state.lastSyncedAt!.isAfter(lastSuccess!), isTrue);
  });

  test('lastSyncedAt survives a restart via prefs', () async {
    await a.categories.insert(const Category(name: '업무', colorHex: '#EF5350'));
    await a.sync.sync(owner);
    final lastSuccess = a.sync.state.lastSyncedAt;

    // Same prefs, fresh service — simulates app relaunch.
    a.connectFresh(cloud);
    expect(a.freshSync.state.lastSyncedAt, lastSuccess);
  });

  test('auto-sync stays quiet when signed out or nothing pending', () async {
    a.auth.currentAccount = null;
    a.sync.start();
    await a.categories.insert(const Category(name: '업무', colorHex: '#EF5350'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(cloud.categories, isEmpty);

    // Signed in but everything synced → refresh-triggered requests no-op.
    a.auth.currentAccount = const AuthAccount(id: owner);
    await a.sync.sync(owner);
    final upsertsAfterSync = cloud.blockUpserts;
    a.sync.requestSync();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(cloud.blockUpserts, upsertsAfterSync);
    a.sync.dispose();
  });
}

/// Mirrors SettingsService's dirty-stamping without dragging in the
/// notification scheduler; timestamps are explicit for deterministic LWW.
class _FakeSettingsEditor {
  final PreferencesPort _prefs;
  _FakeSettingsEditor(this._prefs);

  Future<void> setEnabled(bool value, {required int atMillis}) async {
    await _prefs.setBool(NotificationSettings.keyEnabled, value);
    await _prefs.setInt(SettingsSyncKeys.updatedAtMillis, atMillis);
    await _prefs.setBool(SettingsSyncKeys.dirty, true);
  }
}
