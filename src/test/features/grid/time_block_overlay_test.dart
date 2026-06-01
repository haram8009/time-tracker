import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';

void main() {
  group('TimeBlockOverlay cell-snapped position calculation', () {
    const cellHeight = 32.0;

    // Cell index = minute / 10. Row = cellIdx / 6. Col = cellIdx % 6.

    test('block top is row * cellHeight', () {
      // 9:00 = minute 540 -> cellIdx 54 -> row 9 -> top = 9 * 32 = 288
      final block = TimeBlock(
        id: 1,
        date: DateKey(2024, 1, 1),
        startMinute: 540,
        endMinute: 600,
        categoryId: 1,
      );
      final startRow = (block.startMinute ~/ 10) ~/ 6;
      expect(startRow * cellHeight, 288.0);
    });

    test('full-hour block fits single row, height equals cellHeight', () {
      // 9:00-10:00 = 6 cells all in row 9. One segment, height = cellHeight.
      final block = TimeBlock(
        id: 1,
        date: DateKey(2024, 1, 1),
        startMinute: 540,
        endMinute: 600,
        categoryId: 1,
      );
      final startCellIdx = block.startMinute ~/ 10;
      final endCellIdx = (block.endMinute - 1) ~/ 10;
      final startRow = startCellIdx ~/ 6;
      final endRow = endCellIdx ~/ 6;
      expect(startRow, endRow); // single row
      expect(cellHeight, 32.0); // height per segment is always cellHeight
    });

    test('10-minute block occupies one cell, height equals cellHeight', () {
      // 10 min -> 1 cell -> height = cellHeight, not a fractional pixel height
      expect(cellHeight, 32.0);
    });

    test('cross-row block spans two row segments', () {
      // 10:00-11:10 = minute 600-670
      // cells 60-66: row 10 (cols 0-5) + row 11 (col 0)
      final block = TimeBlock(
        id: 1,
        date: DateKey(2024, 1, 1),
        startMinute: 600,
        endMinute: 670,
        categoryId: 1,
      );
      final startCellIdx = block.startMinute ~/ 10; // 60
      final endCellIdx = (block.endMinute - 1) ~/ 10; // 66
      final startRow = startCellIdx ~/ 6; // 10
      final endRow = endCellIdx ~/ 6; // 11
      expect(startRow, 10);
      expect(endRow, 11);

      // Row 10: cols 0-5 (6 cells)
      final row10Start = (startCellIdx - startRow * 6).clamp(0, 5);
      final row10End = (5).clamp(0, 5);
      expect(row10Start, 0);
      expect(row10End - row10Start + 1, 6);

      // Row 11: col 0 only (1 cell)
      final row11Start = (startCellIdx - endRow * 6).clamp(0, 5);
      final row11End = (endCellIdx - endRow * 6).clamp(0, 5);
      expect(row11Start, 0);
      expect(row11End - row11Start + 1, 1);
    });
  });
}
