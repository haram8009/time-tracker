import 'package:flutter/foundation.dart';
import '../../core/logic/drag_selection_reducer.dart';
import '../../core/models/drag_selection_state.dart';

export '../../core/logic/drag_selection_reducer.dart';
export '../../core/models/drag_selection_state.dart';

class DragSelectionController extends ChangeNotifier {
  DragSelectionState _state = const DragSelectionState();

  DragSelection? get selection => _state.selection;
  Set<int> get selectedIndices => _state.selectedIndices;

  void onDragStart(int cellIndex) {
    _state = dragSelectionReducer(_state, DragStarted(cellIndex));
    notifyListeners();
  }

  void onDragUpdate(int cellIndex) {
    _state = dragSelectionReducer(_state, DragUpdated(cellIndex));
    notifyListeners();
  }

  void onDragEnd() {
    _state = dragSelectionReducer(_state, DragEnded());
    notifyListeners();
  }

  void onDragCancel() {
    _state = dragSelectionReducer(_state, DragCancelled());
    notifyListeners();
  }

  void clearSelection() {
    _state = const DragSelectionState();
    notifyListeners();
  }
}
