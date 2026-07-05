import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/drag_selection_reducer.dart';
import '../../core/logic/grid_layout_calculator.dart';
import '../../core/logic/page_sync_decider.dart';
import '../../core/models/date_key.dart';
import '../../core/models/drag_selection_state.dart';
import 'grid_gesture_handler.dart';

export '../../core/models/drag_selection_state.dart';

/// Grid layout constants shared by the coordinator's calculator and the
/// screen's rendering.
const kGridColumnCount = 6;
const kGridCellHeight = 48.0;
const kGridTimeLabelWidth = 48.0;

/// Single source of truth for grid date navigation (#98): owns the selected
/// date (the [state]), the page/scroll controllers, and every transition
/// between them. The widget only renders state and dispatches user input.
///
/// Echo suppression is structural, not flag-based (#84): the swipe path
/// ([onPageChanged]) never moves the page controller — it is already on the
/// target page — so a fling can never be snapped back by a late echo jump.
/// Only external navigation ([goToDate]: calendar, week strip, today button)
/// consults [decidePageSync] and jumps the controller.
class GridCoordinator extends StateNotifier<DateKey> {
  GridCoordinator({required GridLayoutCalculator calculator})
      : _calculator = calculator,
        super(DateKey.today()) {
    _gestureHandler = GridGestureHandler(
      calculator: calculator,
      onDragStarted: onDragStarted,
      onDragUpdated: onDragUpdated,
      onDragEnded: onDragEnded,
      onDragCancelled: onDragCancelled,
      onDraggingChanged: (v) => isDragging.value = v,
    );

    _pageController =
        PageController(initialPage: DateKey.today().toPage(DateKey.appEpoch));
    _scrollController = ScrollController();
  }

  final GridLayoutCalculator _calculator;

  /// Set by the screen — completing a drag selection opens the category
  /// sheet, which needs a BuildContext the coordinator must not own.
  void Function(DateKey date, DragSelection selection)? onSelectionComplete;

  late final GridGestureHandler _gestureHandler;
  late final PageController _pageController;
  late final ScrollController _scrollController;

  DragSelectionState _dragState = const DragSelectionState();
  final _dragNotifier =
      ValueNotifier<DragSelectionState>(const DragSelectionState());

  double _screenHeight = 0;
  double _topPad = 0;

  final isDragging = ValueNotifier<bool>(false);

  DateKey get selectedDate => state;
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
    if (sel != null) onSelectionComplete?.call(state, sel);
  }

  void onDragCancelled() => _applyDrag(DragCancelled());

  void clearSelection() {
    _dragState = const DragSelectionState();
    _dragNotifier.value = _dragState;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// External navigation (calendar modal, week strip, today button): updates
  /// the date, jumps the page controller when it is elsewhere, and scrolls
  /// (to now for today, to top otherwise). Future dates clamp to today.
  void goToDate(DateKey date) {
    final target = date.clampToToday();
    state = target;

    final targetPage = target.toPage(DateKey.appEpoch);
    final currentPage =
        _pageController.hasClients ? _pageController.page?.round() : null;
    final decision =
        decidePageSync(currentPage: currentPage, targetPage: targetPage);
    if (decision is JumpTo && _pageController.hasClients) {
      _pageController.jumpToPage(decision.page);
    }
    _scrollFor(target);
  }

  void goToToday() => goToDate(DateKey.today());

  /// Swipe path (PageView callback). Never touches the page controller — it
  /// is already on [page]. Fires for programmatic jumps too; those arrive
  /// with the date already set and are ignored.
  void onPageChanged(int page) {
    final date = DateKey.fromPage(page, DateKey.appEpoch);
    if (date == state) return;
    state = date;
    _scrollFor(date);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _dragNotifier.dispose();
    isDragging.dispose();
    super.dispose();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _applyDrag(DragEvent event) {
    _dragState = dragSelectionReducer(_dragState, event);
    _dragNotifier.value = _dragState;
  }

  void _scrollFor(DateKey date) {
    switch (decideScrollTarget(isToday: date == DateKey.today())) {
      case ScrollTarget.toNow:
        _scrollToNow();
      case ScrollTarget.toTop:
        _scrollToTop();
    }
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients || _screenHeight == 0) return;
    final now = DateTime.now();
    final idx = (now.hour * 60 + now.minute) ~/ 10;
    final offset =
        _calculator.scrollTargetForIndex(idx, _screenHeight, _topPad);
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

/// Exposes the coordinator (notifier) and the selected date (state). Lives at
/// provider scope so it survives tab switches, like the screen it backs.
final gridCoordinatorProvider =
    StateNotifierProvider<GridCoordinator, DateKey>((ref) {
  return GridCoordinator(
    calculator: const GridLayoutCalculator(
      columnCount: kGridColumnCount,
      cellHeight: kGridCellHeight,
      timeLabelWidth: kGridTimeLabelWidth,
    ),
  );
});
