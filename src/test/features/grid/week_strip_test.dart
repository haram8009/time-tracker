import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/features/grid/week_strip.dart';

void main() {
  group('weekStartDate', () {
    test('Sunday input returns same date', () {
      const sunday = DateKey(2026, 5, 3);
      expect(weekStartDate(sunday), equals(sunday));
    });

    test('Saturday input returns 6 days earlier Sunday', () {
      const saturday = DateKey(2026, 5, 9);
      expect(weekStartDate(saturday), equals(const DateKey(2026, 5, 3)));
    });

    test('Wednesday crossing month boundary returns correct Sunday', () {
      // 2026-05-06 is Wednesday; week starts 2026-05-03 Sunday
      const wed = DateKey(2026, 5, 6);
      expect(weekStartDate(wed), equals(const DateKey(2026, 5, 3)));
    });

    test('2026-05-01 Friday returns 2026-04-26 Sunday', () {
      const friday = DateKey(2026, 5, 1);
      expect(weekStartDate(friday), equals(const DateKey(2026, 4, 26)));
    });
  });

  group('weekCellState', () {
    const today = DateKey(2026, 5, 29); // Friday
    const selected = DateKey(2026, 5, 27); // Wednesday

    test('future date returns future', () {
      const future = DateKey(2026, 5, 30);
      expect(weekCellState(future, selected, today), WeekCellState.future);
    });

    test('selected date returns selected', () {
      expect(weekCellState(selected, selected, today), WeekCellState.selected);
    });

    test('today (not selected) returns today', () {
      expect(weekCellState(today, selected, today), WeekCellState.today);
    });

    test('past non-selected date returns normal', () {
      const past = DateKey(2026, 5, 25); // Monday
      expect(weekCellState(past, selected, today), WeekCellState.normal);
    });

    test('selected takes priority over today when same date', () {
      expect(weekCellState(today, today, today), WeekCellState.selected);
    });
  });
}
