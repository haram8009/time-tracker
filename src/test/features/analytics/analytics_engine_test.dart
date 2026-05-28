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

  group('computeHeatmap', () {
    TimeBlock hBlock({
      required String date,
      required int start,
      required int end,
      int catId = 1,
    }) =>
        TimeBlock(date: date, startMinute: start, endMinute: end, categoryId: catId);

    test('빈 입력 → 7×24 전부 isEmpty', () {
      final m = AnalyticsEngine.computeHeatmap(blocks: [], categories: []);
      expect(m.length, 7);
      expect(m.every((row) => row.length == 24), isTrue);
      expect(m.every((row) => row.every((c) => c.isEmpty)), isTrue);
    });

    test('월요일 블록(2026-05-25) → 요일 인덱스 0, 분 정확도', () {
      final b = hBlock(date: '2026-05-25', start: 60, end: 120);
      final m = AnalyticsEngine.computeHeatmap(blocks: [b], categories: [cat1]);
      expect(m[0][1].totalMinutes, 60);
      expect(m[0][1].dominantCategory, cat1);
      expect(m[0][2].isEmpty, isTrue);
      expect(m[1][1].isEmpty, isTrue);
    });

    test('부분 겹침(30~90분) → hour 0에 30분, hour 1에 30분', () {
      final b = hBlock(date: '2026-05-25', start: 30, end: 90);
      final m = AnalyticsEngine.computeHeatmap(blocks: [b], categories: [cat1]);
      expect(m[0][0].totalMinutes, 30);
      expect(m[0][1].totalMinutes, 30);
    });

    test('같은 슬롯 같은 카테고리 누적', () {
      final blocks = [
        hBlock(date: '2026-05-25', start: 60, end: 120),
        hBlock(date: '2026-05-25', start: 60, end: 120),
      ];
      final m = AnalyticsEngine.computeHeatmap(blocks: blocks, categories: [cat1]);
      expect(m[0][1].totalMinutes, 120);
      expect(m[0][1].dominantCategory, cat1);
    });

    test('dominant category = 분 많은 카테고리', () {
      final blocks = [
        hBlock(date: '2026-05-25', start: 60, end: 100, catId: 1), // 40분
        hBlock(date: '2026-05-25', start: 100, end: 120, catId: 2), // 20분
      ];
      final m = AnalyticsEngine.computeHeatmap(blocks: blocks, categories: [cat1, cat2]);
      expect(m[0][1].dominantCategory, cat1);
      expect(m[0][1].totalMinutes, 60);
    });

    test('고아 categoryId → dominantCategory null, totalMinutes 유지', () {
      final b = hBlock(date: '2026-05-25', start: 60, end: 120, catId: 99);
      final m = AnalyticsEngine.computeHeatmap(blocks: [b], categories: []);
      expect(m[0][1].totalMinutes, 60);
      expect(m[0][1].dominantCategory, isNull);
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

  group('RetiredCategory 렌더링', () {
    const retiredCat = Category(
      id: 99,
      name: '퇴직카테고리',
      colorHex: '#123456',
      isHidden: true,
    );

    test('computeStats — RetiredCategory 블록 포함', () {
      final stats = AnalyticsEngine.computeStats(
        [block(start: 0, end: 60, categoryId: 99)],
        [retiredCat],
      );
      expect(stats.length, 1);
      expect(stats.first.category, retiredCat);
      expect(stats.first.totalMinutes, 60);
    });

    test('computeHeatmap — RetiredCategory dominantCategory 반환', () {
      final matrix = AnalyticsEngine.computeHeatmap(
        blocks: [
          block(start: 0, end: 60, categoryId: 99, date: '2026-05-25'),
        ],
        categories: [retiredCat],
      );
      // 2026-05-25 = Monday = weekday index 0, hour 0
      expect(matrix[0][0].dominantCategory, retiredCat);
      expect(matrix[0][0].totalMinutes, 60);
    });
  });
}
