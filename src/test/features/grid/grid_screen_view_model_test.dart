// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/database_helper.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/core/services/settings_service.dart';
import 'package:time_tracker/features/grid/grid_screen_view_model.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeStore extends TimeBlockStore {
  _FakeStore(super.db);

  final List<TimeBlock> storedBlocks = [];
  final List<TimeBlock> insertedBlocks = [];

  @override
  Future<TimeBlock> insert(TimeBlock block) async {
    final b = block.copyWith(id: insertedBlocks.length + 1);
    insertedBlocks.add(b);
    storedBlocks.add(b);
    return b;
  }

  @override
  Future<TimeBlock> mergeOrInsert(TimeBlock block) async => insert(block);

  @override
  Future<TimeBlock> replaceRange(TimeBlock block) async => insert(block);

  @override
  Future<List<TimeBlock>> fetchByDate(DateKey date) async =>
      storedBlocks.where((b) => b.date == date.toDbString()).toList();
}

class _FakeNotificationPort implements NotificationPort {
  final List<Map<String, dynamic>> scheduledCalls = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelById(int id) async => cancelledIds.add(id);

  @override
  Future<void> scheduleAtTime({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {
    scheduledCalls.add({'id': id});
  }
}

class _FakePrefs implements PreferencesPort {
  @override
  bool? getBool(String key) => null;
  @override
  int? getInt(String key) => null;
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Future<void> setInt(String key, int value) async {}
}

class _FakeCategoryStore extends CategoryStore {
  _FakeCategoryStore(super.db);

  @override
  Future<void> seedIfNeeded() async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

TimeBlock _block({required String date}) => TimeBlock(
      date: date,
      startMinute: 480,
      endMinute: 600,
      categoryId: 1,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

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
              isPreset INTEGER NOT NULL DEFAULT 0
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

  tearDown(() async => db.close());

  group('GridScreenViewModel.saveBlock', () {
    late _FakeStore store;
    late _FakeNotificationPort port;
    late ProviderContainer container;

    setUp(() {
      store = _FakeStore(db);
      port = _FakeNotificationPort();

      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        timeBlockStoreProvider.overrideWithValue(store),
        notificationPortProvider.overrideWithValue(port),
        settingsServiceProvider.overrideWith(
          (ref) => SettingsService(_FakePrefs(), port),
        ),
        categoryStoreProvider.overrideWithValue(_FakeCategoryStore(db)),
      ]);
    });

    tearDown(() => container.dispose());

    test('오늘 블록 insert → store에 저장됨', () async {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      final block = _block(date: _todayKey());
      await vm.saveBlock(block);
      expect(store.insertedBlocks.length, 1);
      expect(store.insertedBlocks.first.startMinute, 480);
    });

    test('오늘 블록 insert → scheduleSmartNotification 트리거 (cancelById 호출)', () async {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      await vm.saveBlock(_block(date: _todayKey()));
      expect(port.cancelledIds, contains(1));
    });

    test('과거 날짜 블록 insert → 알림 reschedule 없음', () async {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      await vm.saveBlock(_block(date: '2020-01-01'));
      expect(port.cancelledIds, isEmpty);
    });

    test('saveBlock 여러 번 → 각 호출마다 insert', () async {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      await vm.saveBlock(_block(date: _todayKey()));
      await vm.saveBlock(_block(date: _todayKey()));
      expect(store.insertedBlocks.length, 2);
    });
  });

  group('GridScreenViewModel.goToDate', () {
    late ProviderContainer container;

    setUp(() {
      final store = _FakeStore(db);
      final port = _FakeNotificationPort();
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        timeBlockStoreProvider.overrideWithValue(store),
        notificationPortProvider.overrideWithValue(port),
        settingsServiceProvider.overrideWith(
          (ref) => SettingsService(_FakePrefs(), port),
        ),
        categoryStoreProvider.overrideWithValue(_FakeCategoryStore(db)),
      ]);
    });

    tearDown(() => container.dispose());

    test('오늘 날짜 → selectedDate 업데이트', () {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      final today = DateTime.now();
      vm.goToDate(today);
      final state = container.read(gridScreenViewModelProvider);
      expect(state.selectedDate.year, today.year);
      expect(state.selectedDate.month, today.month);
      expect(state.selectedDate.day, today.day);
    });

    test('과거 날짜 → selectedDate 업데이트', () {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      final past = DateTime(2024, 3, 15);
      vm.goToDate(past);
      final state = container.read(gridScreenViewModelProvider);
      expect(state.selectedDate.year, 2024);
      expect(state.selectedDate.month, 3);
      expect(state.selectedDate.day, 15);
    });

    test('미래 날짜 → selectedDate 변경 없음', () {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      final before = container.read(gridScreenViewModelProvider).selectedDate;
      final future = DateTime.now().add(const Duration(days: 1));
      vm.goToDate(future);
      final after = container.read(gridScreenViewModelProvider).selectedDate;
      expect(after.year, before.year);
      expect(after.month, before.month);
      expect(after.day, before.day);
    });

    test('시간 정보 제거 — selectedDate는 자정(0시)으로 정규화', () {
      final vm = container.read(gridScreenViewModelProvider.notifier);
      vm.goToDate(DateTime(2024, 6, 1, 15, 30, 59));
      final state = container.read(gridScreenViewModelProvider);
      expect(state.selectedDate, DateTime(2024, 6, 1));
    });
  });
}
