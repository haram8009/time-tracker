// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/notifications/notification_settings.dart';
import 'package:time_tracker/core/services/block_save_interactor.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeStore extends TimeBlockStore {
  _FakeStore(super.db);

  final List<TimeBlock> replacedBlocks = [];
  final List<TimeBlock> storedBlocks = [];

  @override
  Future<TimeBlock> replaceRange(TimeBlock block) async {
    final b = block.copyWith(id: replacedBlocks.length + 1);
    replacedBlocks.add(b);
    storedBlocks.add(b);
    return b;
  }

  @override
  Future<List<TimeBlock>> fetchByDate(DateKey date) async =>
      storedBlocks.where((b) => b.date == date.toDbString()).toList();
}

class _FakeNotificationPort implements NotificationPort {
  final List<int> cancelledIds = [];
  final List<Map<String, dynamic>> scheduled = [];

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
  }) async =>
      scheduled.add({'id': id});
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

  group('BlockSaveInteractor.save', () {
    late _FakeStore store;
    late _FakeNotificationPort port;

    setUp(() {
      store = _FakeStore(db);
      port = _FakeNotificationPort();
    });

    BlockSaveInteractor makeInteractor({bool notificationsEnabled = true}) =>
        BlockSaveInteractor(
          store: store,
          notificationPort: port,
          settings: NotificationSettings(enabled: notificationsEnabled),
        );

    test('store.replaceRange 호출됨', () async {
      await makeInteractor().save(_block(date: _todayKey()));
      expect(store.replacedBlocks, hasLength(1));
    });

    test('오늘 블록 → cancelById 호출 (scheduleSmartNotification 트리거)', () async {
      await makeInteractor().save(_block(date: _todayKey()));
      expect(port.cancelledIds, contains(1));
    });

    test('과거 날짜 블록 → 알림 reschedule 없음', () async {
      await makeInteractor().save(_block(date: '2020-01-01'));
      expect(port.cancelledIds, isEmpty);
    });

    test('알림 비활성화 → cancelById 호출하지만 scheduleAtTime 없음', () async {
      await makeInteractor(notificationsEnabled: false).save(_block(date: _todayKey()));
      // cancelById is still called (to ensure no stale notification remains)
      expect(port.cancelledIds, contains(1));
      expect(port.scheduled, isEmpty);
    });
  });
}
