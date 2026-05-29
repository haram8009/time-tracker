import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/grid_layout_calculator.dart';

void main() {
  const int columnCount = 6;
  const double cellHeight = 60.0;
  const double timeLabelWidth = 48.0;
  const GridLayoutCalculator calc = GridLayoutCalculator(
    columnCount: columnCount,
    cellHeight: cellHeight,
    timeLabelWidth: timeLabelWidth,
  );

  // Grid size: timeLabelWidth + 6 columns × 60px wide each
  const Size gridSize = Size(timeLabelWidth + columnCount * 60.0, 24 * cellHeight);

  group('cellIndex()', () {
    test('top-left (0,0) → index 0', () {
      expect(calc.cellIndex(Offset.zero, gridSize), 0);
    });

    test('bottom-right corner → last index (143)', () {
      final offset = Offset(gridSize.width - 1, gridSize.height - 1);
      expect(calc.cellIndex(offset, gridSize), 24 * columnCount - 1);
    });

    test('center → expected column and row', () {
      // Row 12 (y = 12 * 60 + 30 = 750), column 3
      // x = timeLabelWidth + 3.5 * 60 = 48 + 210 = 258
      final offset = Offset(258, 750);
      final index = calc.cellIndex(offset, gridSize);
      expect(calc.rowFromIndex(index), 12);
      expect(calc.columnFromIndex(index), 3);
    });

    test('tap inside timeLabelWidth region → column 0', () {
      // x < timeLabelWidth, row 5
      final offset = Offset(10, 5 * cellHeight + 10);
      final index = calc.cellIndex(offset, gridSize);
      expect(calc.columnFromIndex(index), 0);
      expect(calc.rowFromIndex(index), 5);
    });

    test('out-of-bounds negative offset → clamped to 0', () {
      expect(calc.cellIndex(const Offset(-100, -100), gridSize), 0);
    });

    test('out-of-bounds beyond grid → clamped to last index', () {
      final offset = Offset(gridSize.width + 100, gridSize.height + 100);
      expect(calc.cellIndex(offset, gridSize), 24 * columnCount - 1);
    });
  });

  group('scrollTargetForIndex()', () {
    const double viewportHeight = 400.0;
    const double headerHeight = 60.0;

    test('index 0 → returns >= 0', () {
      final result = calc.scrollTargetForIndex(0, viewportHeight, headerHeight);
      expect(result, greaterThanOrEqualTo(0));
    });

    test('index 0 → clamped to 0 since row 0 would be negative', () {
      // row=0: 0 * 60 - (400-60)/2 + 60/2 = 0 - 170 + 30 = -140 → clamped to 0
      expect(calc.scrollTargetForIndex(0, viewportHeight, headerHeight), 0.0);
    });

    test('mid-index → expected scroll value', () {
      // index 72 → row 12, col 0
      // 12 * 60 - (400-60)/2 + 60/2 = 720 - 170 + 30 = 580
      final result = calc.scrollTargetForIndex(72, viewportHeight, headerHeight);
      expect(result, closeTo(580.0, 0.001));
    });

    test('large index in last row → positive scroll value', () {
      final result = calc.scrollTargetForIndex(
        24 * columnCount - 1,
        viewportHeight,
        headerHeight,
      );
      expect(result, greaterThan(0));
    });
  });

  group('rowFromIndex / columnFromIndex round-trip', () {
    test('index 0 → row 0, col 0', () {
      expect(calc.rowFromIndex(0), 0);
      expect(calc.columnFromIndex(0), 0);
    });

    test('index 5 → row 0, col 5', () {
      expect(calc.rowFromIndex(5), 0);
      expect(calc.columnFromIndex(5), 5);
    });

    test('index 6 → row 1, col 0', () {
      expect(calc.rowFromIndex(6), 1);
      expect(calc.columnFromIndex(6), 0);
    });

    test('index 143 → row 23, col 5', () {
      expect(calc.rowFromIndex(143), 23);
      expect(calc.columnFromIndex(143), 5);
    });

    test('round-trip: row/col → index → row/col', () {
      for (int i = 0; i < 24 * columnCount; i++) {
        final row = calc.rowFromIndex(i);
        final col = calc.columnFromIndex(i);
        expect(row * columnCount + col, i);
      }
    });
  });
}
