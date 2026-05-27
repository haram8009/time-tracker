import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:time_tracker/core/db/database_helper.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() => DatabaseHelper.resetForTesting());

  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsAdapterProvider.overrideWithValue(_FakePrefs()),
        ],
        child: const TimeTrackerApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
