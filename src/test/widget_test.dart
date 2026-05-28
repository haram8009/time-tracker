import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:time_tracker/core/db/category_store.dart';
import 'package:time_tracker/core/db/time_block_store.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/core/notifications/notification_port.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/main.dart';

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

class _FakeNotificationPort implements NotificationPort {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> cancelById(int id) async {}
  @override
  Future<void> scheduleAtTime({
    required int id,
    required String title,
    required String body,
    required DateTime fireTime,
  }) async {}
}

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsAdapterProvider.overrideWithValue(_FakePrefs()),
          notificationPortProvider.overrideWithValue(_FakeNotificationPort()),
          // Keep stream providers in AsyncLoading so data-dependent widgets
          // (which would access categoryStoreProvider/DB) are never built.
          categoriesAllStreamProvider.overrideWith(
            (ref) => const Stream<List<Category>>.empty(),
          ),
          categoriesStreamProvider.overrideWith(
            (ref) => const Stream<List<Category>>.empty(),
          ),
          timeBlocksStreamProvider.overrideWith(
            (ref, date) => const Stream<List<TimeBlock>>.empty(),
          ),
          timeBlocksRangeProvider.overrideWith(
            (ref, range) => const Stream<List<TimeBlock>>.empty(),
          ),
        ],
        child: const TimeTrackerApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
