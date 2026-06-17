import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/features/grid/record_dot.dart';

TimeBlock _block(DateKey date) =>
    TimeBlock(date: date, startMinute: 0, endMinute: 10, categoryId: 1);

void main() {
  group('recordDatesOf', () {
    test('empty blocks → empty set', () {
      expect(recordDatesOf(const []), isEmpty);
    });

    test('collapses multiple blocks on same date to one entry', () {
      final blocks = [
        _block(const DateKey(2026, 6, 1)),
        _block(const DateKey(2026, 6, 1)),
        _block(const DateKey(2026, 6, 3)),
      ];
      expect(
        recordDatesOf(blocks),
        {const DateKey(2026, 6, 1), const DateKey(2026, 6, 3)},
      );
    });
  });
}
