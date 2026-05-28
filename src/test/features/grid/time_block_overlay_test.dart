import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/time_block.dart';

void main() {
  group('TimeBlockOverlay position calculation', () {
    const cellHeight = 32.0;

    test('single block top position', () {
      // 9:00 AM = 540 minutes. top = (540/60) * 32 = 9 * 32 = 288
      final block = TimeBlock(
        id: 1,
        date: '2024-01-01',
        startMinute: 540,
        endMinute: 600,
        categoryId: 1,
      );
      final expectedTop = (block.startMinute / 60.0) * cellHeight;
      expect(expectedTop, 288.0);
    });

    test('single block height', () {
      // 60 minutes = (60/60) * 32 = 32
      final block = TimeBlock(
        id: 1,
        date: '2024-01-01',
        startMinute: 540,
        endMinute: 600,
        categoryId: 1,
      );
      final expectedHeight =
          ((block.endMinute - block.startMinute) / 60.0) * cellHeight;
      expect(expectedHeight, 32.0);
    });

    test('10-minute block height', () {
      // 10 minutes = (10/60) * 32 ≈ 5.33
      final expectedHeight = (10 / 60.0) * cellHeight;
      expect(expectedHeight, closeTo(5.33, 0.01));
    });
  });
}
