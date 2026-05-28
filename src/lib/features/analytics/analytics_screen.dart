import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/utils/time_utils.dart';
import 'analytics_engine.dart';
import 'analytics_view_model.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _touchedIndex = -1;

  static const _periods = [
    AnalyticsPeriod.day,
    AnalyticsPeriod.week,
    AnalyticsPeriod.month,
    AnalyticsPeriod.heatmap,
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _periods.length, vsync: this);
    _tab.addListener(() => setState(() => _touchedIndex = -1));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('분석'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '일'), Tab(text: '주'), Tab(text: '월'), Tab(text: '히트맵')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _PeriodView(
            period: AnalyticsPeriod.day,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          _PeriodView(
            period: AnalyticsPeriod.week,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          _PeriodView(
            period: AnalyticsPeriod.month,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          const _HeatmapView(),
        ],
      ),
    );
  }
}

class _PeriodView extends ConsumerWidget {
  final AnalyticsPeriod period;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _PeriodView({
    required this.period,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = AnalyticsViewModel.dateRangeFor(period);
    final blocksAsync = ref.watch(timeBlocksRangeProvider(range));
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return blocksAsync.when(
      data: (blocks) => categoriesAsync.when(
        data: (categories) {
          final stats = AnalyticsEngine.computeStats(blocks, categories);
          final total = stats.fold(0, (s, e) => s + e.totalMinutes);

          if (stats.isEmpty) {
            return Center(
              child: Text(
                '${AnalyticsViewModel.labelFor(period)} 기록이 없어요.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 24),
              SizedBox(
                height: 240,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          onTouch(-1);
                          return;
                        }
                        onTouch(response.touchedSection!.touchedSectionIndex);
                      },
                    ),
                    sections: List.generate(stats.length, (i) {
                      final s = stats[i];
                      final isTouched = i == touchedIndex;
                      final color = hexToColor(s.category.colorHex);
                      final pct = (s.fraction(total) * 100).toStringAsFixed(1);
                      return PieChartSectionData(
                        color: color,
                        value: s.totalMinutes.toDouble(),
                        title: isTouched ? '$pct%' : '',
                        radius: isTouched ? 80 : 64,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }),
                    borderData: FlBorderData(show: false),
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: stats.length,
                  itemBuilder: (context, i) {
                    final s = stats[i];
                    final pct = (s.fraction(total) * 100).toStringAsFixed(1);
                    final h = s.totalMinutes ~/ 60;
                    final m = s.totalMinutes % 60;
                    final timeStr = h > 0 ? '$h시간 $m분' : '$m분';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hexToColor(s.category.colorHex),
                        radius: 10,
                      ),
                      title: Text(s.category.name),
                      trailing: Text('$pct%  $timeStr'),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

class _HeatmapView extends ConsumerWidget {
  const _HeatmapView();

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.heatmap);
    final blocksAsync = ref.watch(timeBlocksRangeProvider(range));
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final threshold = ref.watch(analyticsViewModelProvider).heatmapThreshold;

    return blocksAsync.when(
      data: (blocks) => categoriesAsync.when(
        data: (categories) {
          if (blocks.length < threshold) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '히트맵을 표시하려면\n최소 $threshold개의 기록이 필요해요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final matrix = AnalyticsEngine.computeHeatmap(
            blocks: blocks,
            categories: categories,
          );
          final maxVal = matrix
              .expand((row) => row)
              .fold<int>(0, (a, c) => c.totalMinutes > a ? c.totalMinutes : a);

          return LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 28.0;
              const cellMargin = 2.0;
              const numCells = 24;
              final cellWidth =
                  ((constraints.maxWidth - 32 - labelWidth) / numCells) -
                      cellMargin;
              final clampedCell = cellWidth.clamp(8.0, 20.0);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: labelWidth),
                        ...List.generate(24, (h) {
                          if (h % 3 != 0) {
                            return SizedBox(width: clampedCell + cellMargin);
                          }
                          return SizedBox(
                            width: clampedCell + cellMargin,
                            child: Text(
                              '$h',
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }),
                      ],
                    ),
                    ...List.generate(7, (day) {
                      return Row(
                        children: [
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              _days[day],
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          ...List.generate(24, (hour) {
                            final cell = matrix[day][hour];
                            final intensity = maxVal == 0 || cell.isEmpty
                                ? 0.0
                                : cell.totalMinutes / maxVal;
                            return Container(
                              width: clampedCell,
                              height: clampedCell,
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  Colors.indigo.shade50,
                                  Colors.indigo.shade700,
                                  intensity,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('적음 ', style: TextStyle(fontSize: 11)),
                        ...List.generate(5, (i) {
                          return Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.indigo.shade50,
                                Colors.indigo.shade700,
                                i / 4,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                        const Text(' 많음', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}
