class DragSelection {
  final int startMinute;
  final int endMinute;

  const DragSelection({required this.startMinute, required this.endMinute});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DragSelection &&
          startMinute == other.startMinute &&
          endMinute == other.endMinute;

  @override
  int get hashCode => startMinute.hashCode ^ endMinute.hashCode;

  @override
  String toString() =>
      'DragSelection(startMinute: $startMinute, endMinute: $endMinute)';
}

class DragSelectionState {
  final DragSelection? selection;
  final int? dragStartMinute;

  const DragSelectionState({this.selection, this.dragStartMinute});

  Set<int> get selectedIndices {
    if (selection == null) return {};
    final start = selection!.startMinute ~/ 10;
    final end = selection!.endMinute ~/ 10;
    return Set<int>.from(List.generate(end - start, (i) => start + i));
  }

  DragSelectionState copyWith({
    Object? selection = _sentinel,
    Object? dragStartMinute = _sentinel,
  }) {
    return DragSelectionState(
      selection:
          selection == _sentinel ? this.selection : selection as DragSelection?,
      dragStartMinute: dragStartMinute == _sentinel
          ? this.dragStartMinute
          : dragStartMinute as int?,
    );
  }
}

const Object _sentinel = Object();
