import '../../core/models/category.dart';
import '../../core/models/cell_state.dart';
import '../../core/models/photo_asset.dart';
import '../../core/models/time_block.dart';

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
