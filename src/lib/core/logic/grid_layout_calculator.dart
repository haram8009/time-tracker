import 'dart:ui';

class GridLayoutCalculator {
  const GridLayoutCalculator({
    required this.columnCount,
    required this.cellHeight,
    required this.timeLabelWidth,
  });

  final int columnCount;
  final double cellHeight;
  final double timeLabelWidth;

  /// Returns cell index 0..(24*columnCount - 1), clamped.
  /// Taps within the timeLabelWidth region map to column 0.
  int cellIndex(Offset localOffset, Size gridSize) {
    final double contentWidth = gridSize.width - timeLabelWidth;
    final double columnWidth = contentWidth / columnCount;

    final int row = (localOffset.dy / cellHeight).floor().clamp(0, 23);

    int col;
    if (localOffset.dx < timeLabelWidth) {
      col = 0;
    } else {
      final double xInContent = localOffset.dx - timeLabelWidth;
      col = (xInContent / columnWidth).floor().clamp(0, columnCount - 1);
    }

    return (row * columnCount + col).clamp(0, 24 * columnCount - 1);
  }

  /// Row 0-23 from index.
  int rowFromIndex(int index) => index ~/ columnCount;

  /// Column 0-(columnCount-1) from index.
  int columnFromIndex(int index) => index % columnCount;

  /// Scroll offset so the cell at [index] is centered in viewport.
  /// Clamped to >= 0.
  double scrollTargetForIndex(
    int index,
    double viewportHeight,
    double headerHeight,
  ) {
    final int row = rowFromIndex(index);
    final double target =
        row * cellHeight -
        (viewportHeight - headerHeight) / 2 +
        cellHeight / 2;
    return target < 0 ? 0 : target;
  }
}
