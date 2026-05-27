import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/db/time_block_store.dart';
import '../../core/utils/time_utils.dart';
import 'analytics_engine.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
          tabs: const [Tab(text: '일'), Tab(text: '주'), Tab(text: '월')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _PeriodView(
            period: _Period.day,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          _PeriodView(
            period: _Period.week,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
          _PeriodView(
            period: _Period.month,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
        ],
      ),
    );
  }
}

enum _Period { day, week, month }

class _PeriodView extends ConsumerWidget {
  final _Period period;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _PeriodView({
    required this.period,
    required this.touchedIndex,
    required this.onTouch,
  });

  (String, String) _dateRange() {
    final now = DateTime.now();
    switch (period) {
      case _Period.day:
        final d = dateKey(now);
        return (d, d);
      case _Period.week:
        final mon = now.subtract(Duration(days: now.weekday - 1));
        return (dateKey(mon), dateKey(now));
      case _Period.month:
        final first = DateTime(now.year, now.month, 1);
        return (dateKey(first), dateKey(now));
    }
  }

  String _periodLabel() {
    switch (period) {
      case _Period.day:
        return '오늘';
      case _Period.week:
        return '이번 주';
      case _Period.month:
        return '이번 달';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _dateRange();
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
                '${_periodLabel()} 기록이 없어요.',
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
                        onTouch(
                            response.touchedSection!.touchedSectionIndex);
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

