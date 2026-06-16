import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/logic/drag_selection_reducer.dart';
import '../../core/logic/grid_layout_calculator.dart';
import '../../core/logic/page_sync_decider.dart';
import '../../core/models/date_key.dart';
import '../../core/models/drag_selection_state.dart';
import 'grid_gesture_handler.dart';

export '../../core/models/drag_selection_state.dart';

class GridCoordinator {
  GridCoordinator({
    required GridLayoutCalculator calculator,
    required void Function(DateKey) onDateChanged,
    required void Function(DragSelection) onSelectionComplete,
  }) : _calculator = calculator,
       // ignore: prefer_initializing_formals
       _onDateChanged = onDateChanged,
       // ignore: prefer_initializing_formals
       _onSelectionComplete = onSelectionComplete {
    _gestureHandler = GridGestureHandler(
      calculator: calculator,
      onDragStarted: onDragStarted,
      onDragUpdated: onDragUpdated,
      onDragEnded: onDragEnded,
      onDragCancelled: onDragCancelled,
      onDraggingChanged: (v) => isDragging.value = v,
    );

    final initialPage = DateKey.today().toPage(DateKey.appEpoch);
    _pageController = PageController(initialPage: initialPage);
    _scrollController = ScrollController();
  }

  final GridLayoutCalculator _calculator;
  final void Function(DateKey) _onDateChanged;
  final void Function(DragSelection) _onSelectionComplete;

  late final GridGestureHandler _gestureHandler;
  late final PageController _pageController;
  late final ScrollController _scrollController;

  DragSelectionState _dragState = const DragSelectionState();
  final _dragNotifier = ValueNotifier<DragSelectionState>(const DragSelectionState());

  // 현재 진행 중인 page 변경의 출처. 기본 external.
  // swipe 발 변경은 onPageChanged가 직접 표시 → 뒤따르는 echo goToDate를 NoOp 처리.
  PageChangeSource _source = PageChangeSource.external;

  double _screenHeight = 0;
  double _topPad = 0;

  final isDragging = ValueNotifier<bool>(false);

  ScrollController get scrollController => _scrollController;
  PageController get pageController => _pageController;
  GridGestureHandler get gestureHandler => _gestureHandler;
  ValueListenable<DragSelectionState> get dragState => _dragNotifier;

  void updateMetrics({required double screenHeight, required double topPad}) {
    _screenHeight = screenHeight;
    _topPad = topPad;
  }

  // ── Drag events ────────────────────────────────────────────────────────────

  void onDragStarted(int cellIndex) => _applyDrag(DragStarted(cellIndex));
  void onDragUpdated(int cellIndex) => _applyDrag(DragUpdated(cellIndex));

  void onDragEnded() {
    _applyDrag(DragEnded());
    final sel = _dragState.selection;
    if (sel != null) _onSelectionComplete(sel);
  }

  void onDragCancelled() => _applyDrag(DragCancelled());

  void clearSelection() {
    _dragState = const DragSelectionState();
    _dragNotifier.value = _dragState;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void goToDate(DateKey date) {
    if (date == DateKey.today()) {
      _scrollToNow();
    } else {
      _scrollToTop();
    }
    final targetPage = date.toPage(DateKey.appEpoch);
    final currentPage =
        _pageController.hasClients ? _pageController.page?.round() : null;
    final decision = decidePageSync(
      source: _source,
      currentPage: currentPage,
      targetPage: targetPage,
    );
    if (decision is JumpTo && _pageController.hasClients) {
      _pageController.jumpToPage(decision.page);
    }
    _source = PageChangeSource.external;
  }

  void goToToday() => goToDate(DateKey.today());

  void onPageChanged(int page) {
    _source = PageChangeSource.swipe;
    final date = DateKey.fromPage(page, DateKey.appEpoch);
    _onDateChanged(date);
  }

  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _dragNotifier.dispose();
    isDragging.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _applyDrag(DragEvent event) {
    _dragState = dragSelectionReducer(_dragState, event);
    _dragNotifier.value = _dragState;
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients || _screenHeight == 0) return;
    final now = DateTime.now();
    final idx = (now.hour * 60 + now.minute) ~/ 10;
    final offset = _calculator.scrollTargetForIndex(idx, _screenHeight, _topPad);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
}
