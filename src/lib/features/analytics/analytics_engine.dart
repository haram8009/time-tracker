import '../../core/models/category.dart';
import '../../core/models/time_block.dart';

class CategoryStat {
  final Category category;
  final int totalMinutes;

  const CategoryStat({required this.category, required this.totalMinutes});

  double fraction(int totalTracked) =>
      totalTracked == 0 ? 0 : totalMinutes / totalTracked;
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

  /// Returns a 7×24 matrix: [weekday 0=Mon][hour] = frequency (block count).
  static List<List<int>> computeHeatmap({
    required List<TimeBlock> blocks,
  }) {
    // 7 days × 24 hours
    final matrix = List.generate(7, (_) => List.filled(24, 0));
    for (final b in blocks) {
      final date = DateTime.parse(b.date);
      final dayIndex = date.weekday - 1; // 0=Mon
      // mark every hour the block spans
      final startHour = b.startMinute ~/ 60;
      final endHour = ((b.endMinute - 1) ~/ 60).clamp(0, 23);
      for (var h = startHour; h <= endHour; h++) {
        matrix[dayIndex][h]++;
      }
    }
    return matrix;
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
