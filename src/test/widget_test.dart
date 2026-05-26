import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:time_tracker/main.dart';

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TimeTrackerApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
