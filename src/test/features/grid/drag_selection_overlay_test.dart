import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/features/grid/widgets/drag_selection_overlay.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Finder _descendantsOf(Type overlayType, Type childType) {
  return find.descendant(
    of: find.byType(overlayType),
    matching: find.byType(childType),
  );
}

void main() {
  group('DragSelectionOverlay', () {
    testWidgets('empty selectedIndices → no ColoredBox inside overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 200,
            child: DragSelectionOverlay(
              selectedIndices: {},
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      expect(
        _descendantsOf(DragSelectionOverlay, ColoredBox),
        findsNothing,
      );
    });

    testWidgets('three selectedIndices → three ColoredBox inside overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 200,
            child: DragSelectionOverlay(
              selectedIndices: const {0, 1, 7},
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      expect(
        _descendantsOf(DragSelectionOverlay, ColoredBox),
        findsNWidgets(3),
      );
    });

    testWidgets('overlay contains IgnorePointer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 200,
            child: DragSelectionOverlay(
              selectedIndices: const {0},
              cellHeight: 48,
              timeLabelWidth: 48,
            ),
          ),
        ),
      );

      expect(
        _descendantsOf(DragSelectionOverlay, IgnorePointer),
        findsOneWidget,
      );
    });
  });
}
