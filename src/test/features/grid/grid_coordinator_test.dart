import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/grid_layout_calculator.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/features/grid/drag_selection_controller.dart';
import 'package:time_tracker/features/grid/grid_coordinator.dart';

const _calculator = GridLayoutCalculator(
  columnCount: 6,
  cellHeight: 48,
  timeLabelWidth: 48,
);

GridCoordinator _make({
  void Function(DateKey)? onDateChanged,
  void Function(DragSelection)? onSelectionComplete,
}) =>
    GridCoordinator(
      calculator: _calculator,
      onDateChanged: onDateChanged ?? (_) {},
      onSelectionComplete: onSelectionComplete ?? (_) {},
    );

void main() {
  group('GridCoordinator', () {
    test('pageController initialPage = today', () {
      final c = _make();
      addTearDown(c.dispose);
      expect(c.pageController.initialPage, DateKey.today().toPage(DateKey.appEpoch));
    });

    test('onPageChanged without programmatic jump — onDateChanged called', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      final page = DateKey(2025, 3, 10).toPage(DateKey.appEpoch);
      c.onPageChanged(page);

      expect(called, [DateKey(2025, 3, 10)]);
    });

    test('onPageChanged during programmatic jump — onDateChanged NOT called', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      // goToDate sets _isProgrammaticJump = true when pageController has no clients
      c.goToDate(DateKey(2025, 6, 1));
      c.onPageChanged(DateKey(2025, 6, 1).toPage(DateKey.appEpoch));

      expect(called, isEmpty);
    });

    test('second onPageChanged after jump — onDateChanged called', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      c.goToDate(DateKey(2025, 6, 1));
      c.onPageChanged(DateKey(2025, 6, 1).toPage(DateKey.appEpoch)); // consumed
      final page2 = DateKey(2025, 6, 2).toPage(DateKey.appEpoch);
      c.onPageChanged(page2);

      expect(called, [DateKey(2025, 6, 2)]);
    });

    test('clearSelection delegates to drag controller', () {
      final c = _make();
      addTearDown(c.dispose);

      c.drag.onDragStart(10);
      c.drag.onDragEnd();
      expect(c.drag.selection, isNotNull);

      c.clearSelection();
      expect(c.drag.selection, isNull);
    });

    test('isDragging starts false', () {
      final c = _make();
      addTearDown(c.dispose);
      expect(c.isDragging.value, isFalse);
    });
  });
}
