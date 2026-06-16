import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/grid_layout_calculator.dart';
import 'package:time_tracker/core/models/date_key.dart';
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

    test('onPageChanged(swipe) → onDateChanged 호출 (헤더 즉시 갱신)', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      final page = DateKey(2025, 3, 10).toPage(DateKey.appEpoch);
      c.onPageChanged(page);

      expect(called, [DateKey(2025, 3, 10)]);
    });

    test('연속 onPageChanged — 매번 onDateChanged 호출 (씹힘 없음 — 버그 A)', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      c.onPageChanged(DateKey(2025, 6, 1).toPage(DateKey.appEpoch));
      c.onPageChanged(DateKey(2025, 6, 2).toPage(DateKey.appEpoch));
      c.onPageChanged(DateKey(2025, 6, 3).toPage(DateKey.appEpoch));

      expect(called, [DateKey(2025, 6, 1), DateKey(2025, 6, 2), DateKey(2025, 6, 3)]);
    });

    test('goToDate 자체는 onDateChanged를 호출하지 않음 (echo 차단)', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      c.goToDate(DateKey(2025, 6, 1));

      expect(called, isEmpty);
    });

    test('swipe 뒤 echo goToDate 후에도 다음 onPageChanged 정상 동작 (플래그 미잔존)', () {
      final called = <DateKey>[];
      final c = _make(onDateChanged: called.add);
      addTearDown(c.dispose);

      // 스와이프 → 헤더 갱신 → ref.listen echo goToDate(같은 날짜)
      c.onPageChanged(DateKey(2025, 6, 1).toPage(DateKey.appEpoch));
      c.goToDate(DateKey(2025, 6, 1));
      // 다음 스와이프
      c.onPageChanged(DateKey(2025, 6, 2).toPage(DateKey.appEpoch));

      expect(called, [DateKey(2025, 6, 1), DateKey(2025, 6, 2)]);
    });

    test('clearSelection resets dragState', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(10);
      c.onDragEnded();
      expect(c.dragState.value.selection, isNotNull);

      c.clearSelection();
      expect(c.dragState.value.selection, isNull);
    });

    test('isDragging starts false', () {
      final c = _make();
      addTearDown(c.dispose);
      expect(c.isDragging.value, isFalse);
    });
  });

  group('GridCoordinator drag behavior (replaces DragSelectionController)', () {
    test('단일 셀: onDragStarted(0) + onDragEnded → selection startMinute=0, endMinute=10', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(0);
      c.onDragEnded();

      final sel = c.dragState.value.selection;
      expect(sel, isNotNull);
      expect(sel!.startMinute, 0);
      expect(sel.endMinute, 10);
    });

    test('여러 셀 위→아래: onDragStarted(2) + onDragUpdated(5) + onDragEnded → startMinute=20, endMinute=60', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(2);
      c.onDragUpdated(5);
      c.onDragEnded();

      final sel = c.dragState.value.selection;
      expect(sel!.startMinute, 20);
      expect(sel.endMinute, 60);
    });

    test('여러 셀 아래→위: onDragStarted(5) + onDragUpdated(2) → startMinute=20, endMinute=60', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(5);
      c.onDragUpdated(2);
      c.onDragEnded();

      final sel = c.dragState.value.selection;
      expect(sel!.startMinute, 20);
      expect(sel.endMinute, 60);
    });

    test('onDragCancelled → selection null', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(3);
      c.onDragUpdated(6);
      c.onDragCancelled();

      expect(c.dragState.value.selection, isNull);
    });

    test('selectedIndices 정확성: cellIndex 2→5 → {2,3,4,5}', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(2);
      c.onDragUpdated(5);
      c.onDragEnded();

      expect(c.dragState.value.selectedIndices, {2, 3, 4, 5});
    });

    test('경계값: cellIndex=143 → endMinute=1440', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(143);
      c.onDragEnded();

      expect(c.dragState.value.selection!.endMinute, 1440);
    });

    test('onDragEnded triggers onSelectionComplete callback', () {
      final completed = <DragSelection>[];
      final c = _make(onSelectionComplete: completed.add);
      addTearDown(c.dispose);

      c.onDragStarted(10);
      c.onDragEnded();

      expect(completed, hasLength(1));
      expect(completed.first.startMinute, 100);
    });
  });
}
