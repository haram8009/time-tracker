import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block.dart';
import '../../core/services/block_mutation_service.dart';
import 'grid_view_model.dart';

/// Block lookup/mutation operations for the grid screen. Date navigation
/// state lives in GridCoordinator (#98) — this holds no state of its own.
class GridScreenViewModel {
  final Ref _ref;

  GridScreenViewModel(this._ref);

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
    Provider<GridScreenViewModel>((ref) => GridScreenViewModel(ref));
