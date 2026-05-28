import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/time_block.dart';
import '../../core/services/block_save_interactor.dart';
import 'grid_view_model.dart';

class GridScreenState {
  final DateTime selectedDate;
  final bool dbReady;

  const GridScreenState({required this.selectedDate, required this.dbReady});

  GridScreenState copyWith({DateTime? selectedDate, bool? dbReady}) {
    return GridScreenState(
      selectedDate: selectedDate ?? this.selectedDate,
      dbReady: dbReady ?? this.dbReady,
    );
  }
}

class GridScreenViewModel extends StateNotifier<GridScreenState> {
  final Ref _ref;

  GridScreenViewModel(this._ref)
      : super(GridScreenState(
          selectedDate: DateTime.now(),
          dbReady: true,
        ));

  void goToPreviousDay() =>
      state = state.copyWith(
        selectedDate: state.selectedDate.subtract(const Duration(days: 1)),
      );

  void goToNextDay() {
    final next = state.selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    if (next.year > today.year ||
        (next.year == today.year && next.month > today.month) ||
        (next.year == today.year &&
            next.month == today.month &&
            next.day > today.day)) {
      return;
    }
    state = state.copyWith(selectedDate: next);
  }

  void goToToday() =>
      state = state.copyWith(selectedDate: DateTime.now());

  TimeBlock? blockAtIndex(int index, List<TimeBlock> blocks) {
    final cellStart = GridViewModel.indexToMinute(index);
    final cellEnd = cellStart + 10;
    for (final b in blocks) {
      if (b.startMinute < cellEnd && b.endMinute > cellStart) return b;
    }
    return null;
  }

  Future<void> saveBlock(TimeBlock block) async {
    await _ref.read(blockSaveInteractorProvider).save(block);
  }
}

final gridScreenViewModelProvider =
    StateNotifierProvider<GridScreenViewModel, GridScreenState>(
        (ref) => GridScreenViewModel(ref));
