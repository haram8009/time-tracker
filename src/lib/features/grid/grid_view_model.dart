import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/category.dart';
import '../../core/models/cell_state.dart';
import '../../core/models/date_key.dart';
import '../../core/models/photo_asset.dart';
import '../../core/models/time_block.dart';
import '../../core/services/photo_library_service.dart';

class GridViewModel {
  static List<CellState> compute({
    required List<TimeBlock> blocks,
    required List<Category> categories, // kept for API compatibility
    required List<PhotoAsset> photos,
    required Set<int> selectedIndices,
  }) {
    final thumbnailMap = <int, List<dynamic>>{};
    for (final photo in photos) {
      final idx = minuteToIndex(photo.takenMinute);
      if (idx >= 0 && idx < 144) {
        thumbnailMap.putIfAbsent(idx, () => []);
        if (thumbnailMap[idx]!.length < 2) {
          thumbnailMap[idx]!.add(photo.thumbnailBytes);
        }
      }
    }

    return List.generate(144, (index) {
      return CellState(
        thumbnails: List.from(thumbnailMap[index] ?? const []),
        isSelected: selectedIndices.contains(index),
      );
    });
  }

  static int minuteToIndex(int minute) => minute ~/ 10;
  static int indexToMinute(int index) => index * 10;
}

/// Everything one grid page needs, resolved together (#100) so the widget
/// consumes a single AsyncValue instead of hand-composing nested `.when`s.
typedef GridPageData = ({
  List<TimeBlock> blocks,
  List<Category> categories,
  List<PhotoAsset> photos,
});

/// Combines blocks + categories (+ best-effort photos) for [date]. Loading or
/// error in blocks/categories propagates; photos never block the grid — they
/// degrade to an empty list while loading or on failure.
final gridPageDataProvider = Provider.family<AsyncValue<GridPageData>, DateKey>(
  (ref, date) {
    final blocks = ref.watch(timeBlocksStreamProvider(date));
    final categories = ref.watch(categoriesAllStreamProvider);
    final photos = ref.watch(photosForDateProvider(date.toDateTime()));

    if (blocks.hasError) {
      return AsyncError(blocks.error!, blocks.stackTrace ?? StackTrace.current);
    }
    if (categories.hasError) {
      return AsyncError(
        categories.error!,
        categories.stackTrace ?? StackTrace.current,
      );
    }
    if (blocks.isLoading || categories.isLoading) return const AsyncLoading();

    return AsyncData((
      blocks: blocks.requireValue,
      categories: categories.requireValue,
      photos: photos.valueOrNull ?? const [],
    ));
  },
);
