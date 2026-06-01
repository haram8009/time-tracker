// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/notifications/notification_settings.dart';
import 'package:time_tracker/core/services/block_mutation_service.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeStore extends TimeBlockStore {
  _FakeStore(super.db);

  final List<TimeBlock> replacedBlocks = [];
  final List<int> deletedIds = [];
  final List<TimeBlock> storedBlocks = [];

  @override
  Future<TimeBlock> replaceRange(TimeBlock block) async {
    final b = block.copyWith(id: replacedBlocks.length + 1);
    replacedBlocks.add(b);
    storedBlocks.add(b);
    return b;
  }

  @override
  Future<void> delete(int id) async {
    deletedIds.add(id);
    storedBlocks.removeWhere((b) => b.id == id);
  }

  @override
  Future<List<TimeBlock>> fetchByDate(DateKey date) async =>
      storedBlocks.where((b) => b.date == date).toList();
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

TimeBlock _block({required DateKey date}) => TimeBlock(
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

  group('BlockMutationService', () {
    late _FakeStore store;
    late _FakeNotificationPort port;

    setUp(() {
      store = _FakeStore(db);
      port = _FakeNotificationPort();
    });

    BlockMutationService makeService() => BlockMutationService(
          store: store,
          notificationPort: port,
          settings: const NotificationSettings(enabled: true),
        );

    test('save() 오늘 날짜 → 알림 reschedule됨', () async {
      await makeService().save(_block(date: DateKey.today()));
      expect(port.cancelledIds, contains(1));
    });

    test('save() 과거 날짜 → 알림 reschedule 없음', () async {
      await makeService().save(_block(date: DateKey(2020, 1, 1)));
      expect(port.cancelledIds, isEmpty);
    });

    test('delete() 오늘 날짜 → 알림 reschedule됨', () async {
      await makeService().delete(1, DateKey.today());
      expect(port.cancelledIds, contains(1));
    });

    test('delete() 과거 날짜 → 알림 reschedule 없음', () async {
      final pastDate = DateKey.fromDateTime(DateTime(2020, 1, 1));
      await makeService().delete(1, pastDate);
      expect(port.cancelledIds, isEmpty);
    });
  });
}
