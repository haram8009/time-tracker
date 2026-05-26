import 'dart:ui';
import '../../core/models/cell_state.dart';
import '../../core/models/photo_asset.dart';

class TimeBlock {
  final int startMinute;
  final int endMinute;
  final Color categoryColor;

  const TimeBlock({
    required this.startMinute,
    required this.endMinute,
    required this.categoryColor,
  });
}

class GridViewModel {
  static List<CellState> compute({
    required List<TimeBlock> blocks,
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
      Color? color;
      final cellStart = indexToMinute(index);
      final cellEnd = cellStart + 10;

      for (final block in blocks) {
        if (block.startMinute < cellEnd && block.endMinute > cellStart) {
          color = block.categoryColor;
          break;
        }
      }

      return CellState(
        categoryColor: color,
        thumbnails: List.from(thumbnailMap[index] ?? const []),
        isSelected: selectedIndices.contains(index),
      );
    });
  }

  static int minuteToIndex(int minute) => minute ~/ 10;
  static int indexToMinute(int index) => index * 10;
}
