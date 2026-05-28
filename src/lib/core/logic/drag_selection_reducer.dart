import 'dart:math';
import '../models/drag_selection_state.dart';

sealed class DragEvent {}

class DragStarted extends DragEvent {
  final int cellIndex;
  DragStarted(this.cellIndex);
}

class DragUpdated extends DragEvent {
  final int cellIndex;
  DragUpdated(this.cellIndex);
}

class DragEnded extends DragEvent {}

class DragCancelled extends DragEvent {}

DragSelectionState dragSelectionReducer(
  DragSelectionState state,
  DragEvent event,
) {
  switch (event) {
    case DragStarted(:final cellIndex):
      final startMinute = _snap(cellIndex * 10);
      return DragSelectionState(
        dragStartMinute: startMinute,
        selection: DragSelection(
          startMinute: startMinute,
          endMinute: startMinute + 10,
        ),
      );

    case DragUpdated(:final cellIndex):
      if (state.dragStartMinute == null) return state;
      final current = _snap(cellIndex * 10);
      final a = state.dragStartMinute!;
      return state.copyWith(
        selection: DragSelection(
          startMinute: min(a, current),
          endMinute: max(a, current) + 10,
        ),
      );

    case DragEnded():
      return state.copyWith(dragStartMinute: null);

    case DragCancelled():
      return const DragSelectionState();
  }
}

int _snap(int minute) => (minute ~/ 10) * 10;
