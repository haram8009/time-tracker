import '../../core/models/category.dart';
import '../../core/models/time_block.dart';

class CategoryStat {
  final Category category;
  final int totalMinutes;

  const CategoryStat({required this.category, required this.totalMinutes});

  double fraction(int totalTracked) =>
      totalTracked == 0 ? 0 : totalMinutes / totalTracked;
}

class HeatmapCell {
  final Category? dominantCategory;
  final int totalMinutes;

  const HeatmapCell({this.dominantCategory, required this.totalMinutes});

  bool get isEmpty => totalMinutes == 0;
}

class AnalyticsEngine {
  static List<CategoryStat> computeDailyStats({
    required List<TimeBlock> blocks,
    required List<Category> categories,
  }) =>
      computeStats(blocks, categories);

  static List<CategoryStat> computeWeeklyStats({
    required List<List<TimeBlock>> weekBlocks,
    required List<Category> categories,
  }) =>
      computeStats(weekBlocks.expand((b) => b).toList(), categories);

  static List<CategoryStat> computeMonthlyStats({
    required List<List<TimeBlock>> monthBlocks,
    required List<Category> categories,
  }) =>
      computeStats(monthBlocks.expand((b) => b).toList(), categories);

  /// Returns a 7×24 matrix: [weekday 0=Mon][hour] = HeatmapCell (dominant category + total minutes).
  static List<List<HeatmapCell>> computeHeatmap({
    required List<TimeBlock> blocks,
    required List<Category> categories,
  }) {
    final catMap = <int, Category>{
      for (final c in categories)
        if (c.id != null) c.id!: c,
    };
    final rawMatrix = List.generate(7, (_) => List.generate(24, (_) => <int, int>{}));

    for (final b in blocks) {
      final dayIndex = DateTime.parse(b.date).weekday - 1;
      final startHour = b.startMinute ~/ 60;
      final endHour = ((b.endMinute - 1) ~/ 60).clamp(0, 23);
      for (var h = startHour; h <= endHour; h++) {
        final hourStart = h * 60;
        final overlap = (b.endMinute < hourStart + 60 ? b.endMinute : hourStart + 60) -
            (b.startMinute > hourStart ? b.startMinute : hourStart);
        if (overlap > 0) {
          final cell = rawMatrix[dayIndex][h];
          cell[b.categoryId] = (cell[b.categoryId] ?? 0) + overlap;
        }
      }
    }

    return List.generate(7, (day) {
      return List.generate(24, (hour) {
        final cell = rawMatrix[day][hour];
        if (cell.isEmpty) return const HeatmapCell(totalMinutes: 0);
        final total = cell.values.fold(0, (a, b) => a + b);
        final dominantId = cell.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        return HeatmapCell(dominantCategory: catMap[dominantId], totalMinutes: total);
      });
    });
  }

  static List<CategoryStat> computeStats(
    List<TimeBlock> blocks,
    List<Category> categories,
  ) {
    final catMap = <int, Category>{
      for (final c in categories)
        if (c.id != null) c.id!: c,
    };
    final minuteMap = <int, int>{};
    for (final b in blocks) {
      final duration = b.endMinute - b.startMinute;
      if (duration > 0) {
        minuteMap[b.categoryId] = (minuteMap[b.categoryId] ?? 0) + duration;
      }
    }
    return minuteMap.entries
        .where((e) => catMap.containsKey(e.key))
        .map((e) => CategoryStat(category: catMap[e.key]!, totalMinutes: e.value))
        .toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  }
}
