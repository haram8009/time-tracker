import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block.dart';
import '../../core/services/block_mutation_service.dart';
import 'grid_view_model.dart';

class GridScreenState {
  final DateKey selectedDate;

  const GridScreenState({required this.selectedDate});

  GridScreenState copyWith({DateKey? selectedDate}) {
    return GridScreenState(
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class GridScreenViewModel extends StateNotifier<GridScreenState> {
  final Ref _ref;

  GridScreenViewModel(this._ref)
      : super(GridScreenState(
          selectedDate: DateKey.today(),
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

  /// CasualCategoryCreation: create a category, then save a block onto it.
  /// Ordering matters — the block needs the new category's id.
  Future<void> createCategoryAndSaveBlock({
    required String name,
    required String colorHex,
    required DateKey date,
    required int startMinute,
    required int endMinute,
  }) async {
    final created = await _ref
        .read(categoryStoreProvider)
        .insert(Category(name: name, colorHex: colorHex));
    await saveBlock(TimeBlock(
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      categoryId: created.id!,
    ));
  }
}

final gridScreenViewModelProvider =
    StateNotifierProvider<GridScreenViewModel, GridScreenState>(
        (ref) => GridScreenViewModel(ref));
