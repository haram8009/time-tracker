import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block.dart';
import '../../core/services/block_mutation_service.dart';
import 'grid_view_model.dart';

class GridScreenState {
  final DateKey selectedDate;
  final bool dbReady;

  const GridScreenState({required this.selectedDate, required this.dbReady});

  GridScreenState copyWith({DateKey? selectedDate, bool? dbReady}) {
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
          selectedDate: DateKey.today(),
          dbReady: true,
        ));

  void goToPreviousDay() =>
      state = state.copyWith(
        selectedDate: state.selectedDate.add(const Duration(days: -1)),
      );

  void goToNextDay() {
    final next = state.selectedDate.add(const Duration(days: 1));
    if (next.isAfter(DateKey.today())) return;
    state = state.copyWith(selectedDate: next);
  }

  void goToDate(DateKey date) {
    if (date.isAfter(DateKey.today())) return;
    state = state.copyWith(selectedDate: date);
  }

  void goToToday() =>
      state = state.copyWith(selectedDate: DateKey.today());

  TimeBlock? blockAtIndex(int index, List<TimeBlock> blocks) {
    final cellStart = GridViewModel.indexToMinute(index);
    final cellEnd = cellStart + 10;
    for (final b in blocks) {
      if (b.startMinute < cellEnd && b.endMinute > cellStart) return b;
    }
    return null;
  }

  Future<void> saveBlock(TimeBlock block) async {
    await _ref.read(blockMutationServiceProvider).save(block);
  }
}

final gridScreenViewModelProvider =
    StateNotifierProvider<GridScreenViewModel, GridScreenState>(
        (ref) => GridScreenViewModel(ref));
