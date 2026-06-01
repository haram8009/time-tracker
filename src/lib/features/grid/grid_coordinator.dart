import 'package:flutter/material.dart';

import '../../core/logic/grid_layout_calculator.dart';
import '../../core/models/date_key.dart';
import 'drag_selection_controller.dart';
import 'grid_gesture_handler.dart';

class GridCoordinator {
  GridCoordinator({
    required GridLayoutCalculator calculator,
    required void Function(DateKey) onDateChanged,
    required void Function(DragSelection) onSelectionComplete,
  }) : _calculator = calculator,
       _onDateChanged = onDateChanged {
    _drag = DragSelectionController();

    _gestureHandler = GridGestureHandler(
      calculator: calculator,
      drag: _drag,
      onDraggingChanged: (v) => isDragging.value = v,
      onSelectionComplete: (sel) {
        onSelectionComplete(sel);
      },
      onSelectionCancelled: () {},
    );

    final initialPage = DateKey.today().toPage(DateKey.appEpoch);
    _pageController = PageController(initialPage: initialPage);
    _scrollController = ScrollController();
  }

  final GridLayoutCalculator _calculator;
  final void Function(DateKey) _onDateChanged;

  late final DragSelectionController _drag;
  late final GridGestureHandler _gestureHandler;
  late final PageController _pageController;
  late final ScrollController _scrollController;

  bool _isProgrammaticJump = false;

  double _screenHeight = 0;
  double _topPad = 0;

  final isDragging = ValueNotifier<bool>(false);

  ScrollController get scrollController => _scrollController;
  PageController get pageController => _pageController;
  DragSelectionController get drag => _drag;
  GridGestureHandler get gestureHandler => _gestureHandler;

  void updateMetrics({required double screenHeight, required double topPad}) {
    _screenHeight = screenHeight;
    _topPad = topPad;
  }

  void goToDate(DateKey date) {
    if (date == DateKey.today()) {
      _scrollToNow();
    } else {
      _scrollToTop();
    }
    final targetPage = date.toPage(DateKey.appEpoch);
    _isProgrammaticJump = true;
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetPage) {
      _pageController.jumpToPage(targetPage);
    }
  }

  void goToToday() => goToDate(DateKey.today());

  void onPageChanged(int page) {
    if (_isProgrammaticJump) {
      _isProgrammaticJump = false;
      return;
    }
    final date = DateKey.fromPage(page, DateKey.appEpoch);
    _onDateChanged(date);
  }

  void clearSelection() => _drag.clearSelection();

  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _drag.dispose();
    isDragging.dispose();
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
