import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/logic/grid_layout_calculator.dart';
import 'drag_selection_controller.dart';

class GridGestureHandler {
  GridGestureHandler({
    required this.calculator,
    required this.drag,
    required this.onDraggingChanged,
    required this.onSelectionComplete,
    required this.onSelectionCancelled,
  });

  final GridLayoutCalculator calculator;
  final DragSelectionController drag;
  final void Function(bool) onDraggingChanged;
  final void Function(DragSelection) onSelectionComplete;
  final VoidCallback onSelectionCancelled;

  bool _isDragging = false;

  /// Must be set before gesture events arrive (updated in build).
  Size gridSize = Size.zero;

  void handleLongPressStart(LongPressStartDetails details) {
    if (details.localPosition.dx < calculator.timeLabelWidth) return;
    HapticFeedback.mediumImpact();
    drag.onDragStart(calculator.cellIndex(details.localPosition, gridSize));
    _isDragging = true;
    onDraggingChanged(true);
  }

  void handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) return;
    drag.onDragUpdate(calculator.cellIndex(details.localPosition, gridSize));
  }

  void handleLongPressEnd(LongPressEndDetails details) {
    if (!_isDragging) return;
    drag.onDragEnd();
    _isDragging = false;
    onDraggingChanged(false);
    final sel = drag.selection;
    if (sel != null) onSelectionComplete(sel);
  }

  void handleLongPressCancel() {
    if (!_isDragging) return;
    drag.onDragCancel();
    _isDragging = false;
    onDraggingChanged(false);
    onSelectionCancelled();
  }
}
