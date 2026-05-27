import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/category.dart';
import 'package:time_tracker/core/models/time_block.dart';
import 'package:time_tracker/features/analytics/analytics_engine.dart';

void main() {
  const cat1 = Category(id: 1, name: 'Work', colorHex: '#FF0000');
  const cat2 = Category(id: 2, name: 'Rest', colorHex: '#0000FF');

  TimeBlock block({
    required int start,
    required int end,
    int categoryId = 1,
    String date = '2026-05-27',
  }) =>
      TimeBlock(
        date: date,
        startMinute: start,
        endMinute: end,
        categoryId: categoryId,
      );

  group('AnalyticsEngine.computeStats', () {
    test('빈 입력 → 빈 결과', () {
      expect(AnalyticsEngine.computeStats([], []), isEmpty);
    });

    test('카테고리 없는 블록 → 결과 없음', () {
      final stats = AnalyticsEngine.computeStats([block(start: 0, end: 60)], []);
      expect(stats, isEmpty);
    });

    test('블록 1개 → 분 계산', () {
      final stats = AnalyticsEngine.computeStats(
        [block(start: 0, end: 60)],
        [cat1],
      );
      expect(stats.length, 1);
      expect(stats.first.category, cat1);
      expect(stats.first.totalMinutes, 60);
    });

    test('같은 카테고리 블록 합산', () {
      final stats = AnalyticsEngine.computeStats(
        [block(start: 0, end: 30), block(start: 60, end: 120)],
        [cat1],
      );
      expect(stats.first.totalMinutes, 90);
    });

    test('여러 카테고리 분리', () {
      final stats = AnalyticsEngine.computeStats(
        [
          block(start: 0, end: 60, categoryId: 1),
          block(start: 60, end: 120, categoryId: 2),
        ],
        [cat1, cat2],
      );
      expect(stats.length, 2);
      expect(stats.first.totalMinutes, 60); // 정렬: 내림차순
    });

    test('내림차순 정렬', () {
      final stats = AnalyticsEngine.computeStats(
        [
          block(start: 0, end: 30, categoryId: 1),
          block(start: 0, end: 120, categoryId: 2),
        ],
        [cat1, cat2],
      );
      expect(stats[0].category, cat2);
      expect(stats[1].category, cat1);
    });

    test('fraction 계산', () {
      final stats = AnalyticsEngine.computeStats(
        [
          block(start: 0, end: 60, categoryId: 1),
          block(start: 0, end: 60, categoryId: 2),
        ],
        [cat1, cat2],
      );
      final total = stats.fold(0, (s, e) => s + e.totalMinutes);
      expect(stats[0].fraction(total), 0.5);
      expect(stats[1].fraction(total), 0.5);
    });

    test('fraction 0 when totalTracked=0', () {
      final s = CategoryStat(category: cat1, totalMinutes: 60);
      expect(s.fraction(0), 0.0);
    });

    test('duration 0인 블록 무시', () {
      final stats = AnalyticsEngine.computeStats(
        [block(start: 60, end: 60)], // 0분
        [cat1],
      );
      expect(stats, isEmpty);
    });
  });

  group('named constructors', () {
    test('computeDailyStats', () {
      final stats = AnalyticsEngine.computeDailyStats(
        blocks: [block(start: 0, end: 30)],
        categories: [cat1],
      );
      expect(stats.first.totalMinutes, 30);
    });

    test('computeWeeklyStats', () {
      final stats = AnalyticsEngine.computeWeeklyStats(
        weekBlocks: [
          [block(start: 0, end: 30)],
          [block(start: 0, end: 30)],
        ],
        categories: [cat1],
      );
      expect(stats.first.totalMinutes, 60);
    });

    test('computeMonthlyStats', () {
      final stats = AnalyticsEngine.computeMonthlyStats(
        monthBlocks: List.generate(4, (_) => [block(start: 0, end: 15)]),
        categories: [cat1],
      );
      expect(stats.first.totalMinutes, 60);
    });
  });
}
