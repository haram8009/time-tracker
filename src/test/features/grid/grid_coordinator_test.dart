import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/grid_layout_calculator.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/features/grid/grid_coordinator.dart';

const _calculator = GridLayoutCalculator(
  columnCount: kGridColumnCount,
  cellHeight: kGridCellHeight,
  timeLabelWidth: kGridTimeLabelWidth,
);

GridCoordinator _make() => GridCoordinator(calculator: _calculator);

int _pageOf(DateKey d) => d.toPage(DateKey.appEpoch);

/// Minimal harness attaching the coordinator's PageController to a real
/// PageView, so jump/no-jump behavior is observable without GridScreen.
Widget _harness(GridCoordinator c) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: PageView.builder(
          controller: c.pageController,
          onPageChanged: c.onPageChanged,
          itemCount: _pageOf(DateKey.today()) + 1,
          itemBuilder: (_, page) => Text('page $page'),
        ),
      ),
    );

void main() {
  group('GridCoordinator — 날짜 네비게이션 (단일 출처, #98)', () {
    test('초기 상태: selectedDate = 오늘, pageController.initialPage = 오늘', () {
      final c = _make();
      addTearDown(c.dispose);
      expect(c.state, DateKey.today());
      expect(c.pageController.initialPage, _pageOf(DateKey.today()));
    });

    test('onPageChanged(swipe) → 상태 즉시 갱신 (헤더 반영)', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onPageChanged(_pageOf(DateKey(2025, 3, 10)));

      expect(c.state, DateKey(2025, 3, 10));
    });

    test('연속 onPageChanged — 매번 상태 갱신 (씹힘 없음, #84 버그 A)', () {
      final c = _make();
      addTearDown(c.dispose);
      final seen = <DateKey>[];
      c.addListener(seen.add, fireImmediately: false);

      c.onPageChanged(_pageOf(DateKey(2025, 6, 1)));
      c.onPageChanged(_pageOf(DateKey(2025, 6, 2)));
      c.onPageChanged(_pageOf(DateKey(2025, 6, 3)));

      expect(seen,
          [DateKey(2025, 6, 1), DateKey(2025, 6, 2), DateKey(2025, 6, 3)]);
    });

    test('onPageChanged(현재 날짜와 동일) → 상태 재발행 없음 (jump echo 무시)', () {
      final c = _make();
      addTearDown(c.dispose);
      c.goToDate(DateKey(2025, 6, 1));
      final seen = <DateKey>[];
      c.addListener(seen.add, fireImmediately: false);

      c.onPageChanged(_pageOf(DateKey(2025, 6, 1)));

      expect(seen, isEmpty);
    });

    test('goToDate → 상태 갱신; 미래 날짜는 오늘로 클램프', () {
      final c = _make();
      addTearDown(c.dispose);

      c.goToDate(DateKey(2024, 3, 15));
      expect(c.state, DateKey(2024, 3, 15));

      c.goToDate(DateKey.today().add(const Duration(days: 1)));
      expect(c.state, DateKey.today());
    });

    test('goToToday → 오늘', () {
      final c = _make();
      addTearDown(c.dispose);
      c.goToDate(DateKey(2024, 3, 15));
      c.goToToday();
      expect(c.state, DateKey.today());
    });
  });

  group('GridCoordinator — page 동기화 (PageView 하네스)', () {
    testWidgets('swipe 경로는 컨트롤러를 절대 움직이지 않음 — 빠른 플링 snapback 불가 (#84 버그 B)',
        (tester) async {
      final c = _make();
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));

      final settled = _pageOf(DateKey.today());

      // 플링 중 지나친 페이지들의 onPageChanged가 늦게 도착하는 상황:
      // 컨트롤러는 이미 settled에 있고, 콜백만 과거 페이지들로 연달아 온다.
      c.onPageChanged(settled - 3);
      c.onPageChanged(settled - 2);
      await tester.pump();

      // 컨트롤러는 그대로 — 어떤 echo 점프도 없다.
      expect(c.pageController.page!.round(), settled);
      // 상태는 마지막 콜백을 따른다.
      expect(c.state, DateKey.fromPage(settled - 2, DateKey.appEpoch));
    });

    testWidgets('외부 goToDate → 컨트롤러가 목표 페이지로 점프', (tester) async {
      final c = _make();
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));

      final target = DateKey.today().add(const Duration(days: -30));
      c.goToDate(target);
      await tester.pumpAndSettle();

      expect(c.pageController.page!.round(), _pageOf(target));
      expect(c.state, target);
    });

    testWidgets('외부 goToDate(현재 페이지) → 점프 없음 (NoOp)', (tester) async {
      final c = _make();
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));

      c.goToDate(DateKey.today());
      await tester.pump();

      expect(c.pageController.page!.round(), _pageOf(DateKey.today()));
    });

    testWidgets(
        '#84 재현: 느린 연속 스와이프 — 스와이프마다 헤더 날짜가 실제 페이지와 일치',
        (tester) async {
      final c = _make();
      addTearDown(c.dispose);
      await tester.pumpWidget(_harness(c));

      // 왼쪽으로(과거) 세 번 스와이프, 매번 상태가 페이지를 따라와야 한다.
      for (var i = 1; i <= 3; i++) {
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();
        expect(c.pageController.page!.round(), _pageOf(DateKey.today()) - i);
        expect(c.state, DateKey.fromPage(c.pageController.page!.round(),
            DateKey.appEpoch));
      }
    });
  });

  group('GridCoordinator — drag behavior', () {
    test('단일 셀: onDragStarted(0) + onDragEnded → selection 0..10', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(0);
      c.onDragEnded();

      final sel = c.dragState.value.selection;
      expect(sel, isNotNull);
      expect(sel!.startMinute, 0);
      expect(sel.endMinute, 10);
    });

    test('여러 셀 위→아래: 2→5 → 20..60', () {
      final c = _make();
      addTearDown(c.dispose);

      c.onDragStarted(2);
      c.onDragUpdated(5);
      c.onDragEnded();

      final sel = c.dragState.value.selection;
      expect(sel!.startMinute, 20);
      expect(sel.endMinute, 60);
    });

    test('여러 셀 아래→위: 5→2 → 20..60', () {
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

    test('selectedIndices 정확성: 2→5 → {2,3,4,5}', () {
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

    test('onDragEnded → onSelectionComplete(현재 날짜, selection) 호출', () {
      final c = _make();
      addTearDown(c.dispose);
      final completed = <(DateKey, DragSelection)>[];
      c.onSelectionComplete = (date, sel) => completed.add((date, sel));
      c.goToDate(DateKey(2025, 6, 1));

      c.onDragStarted(10);
      c.onDragEnded();

      expect(completed, hasLength(1));
      expect(completed.single.$1, DateKey(2025, 6, 1));
      expect(completed.single.$2.startMinute, 100);
    });

    test('clearSelection resets dragState; isDragging starts false', () {
      final c = _make();
      addTearDown(c.dispose);
      expect(c.isDragging.value, isFalse);

      c.onDragStarted(10);
      c.onDragEnded();
      expect(c.dragState.value.selection, isNotNull);

      c.clearSelection();
      expect(c.dragState.value.selection, isNull);
    });
  });
}
