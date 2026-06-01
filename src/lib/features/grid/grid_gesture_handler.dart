import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/logic/grid_layout_calculator.dart';

class GridGestureHandler {
  GridGestureHandler({
    required this.calculator,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
    required this.onDragCancelled,
    required this.onDraggingChanged,
  });

  final GridLayoutCalculator calculator;
  final void Function(int cellIndex) onDragStarted;
  final void Function(int cellIndex) onDragUpdated;
  final void Function() onDragEnded;
  final void Function() onDragCancelled;
  final void Function(bool) onDraggingChanged;

  bool _isDragging = false;

  /// Must be set before gesture events arrive (updated in build).
  Size gridSize = Size.zero;

  void handleLongPressStart(LongPressStartDetails details) {
    if (details.localPosition.dx < calculator.timeLabelWidth) return;
    HapticFeedback.mediumImpact();
    onDragStarted(calculator.cellIndex(details.localPosition, gridSize));
    _isDragging = true;
    onDraggingChanged(true);
  }

  void handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) return;
    onDragUpdated(calculator.cellIndex(details.localPosition, gridSize));
  }

  void handleLongPressEnd(LongPressEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    onDraggingChanged(false);
    onDragEnded();
  }

  void handleLongPressCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    onDraggingChanged(false);
    onDragCancelled();
  }
}
