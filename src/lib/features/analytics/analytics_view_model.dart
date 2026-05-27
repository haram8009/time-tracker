import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/preferences_port.dart';
import '../../core/utils/time_utils.dart';

enum AnalyticsPeriod { day, week, month, heatmap }

class AnalyticsState {
  final int heatmapThreshold;

  const AnalyticsState({this.heatmapThreshold = 5});

  AnalyticsState copyWith({int? heatmapThreshold}) => AnalyticsState(
        heatmapThreshold: heatmapThreshold ?? this.heatmapThreshold,
      );
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  static const _keyThreshold = 'heatmap_threshold';

  final PreferencesPort _prefs;

  AnalyticsViewModel(this._prefs) : super(const AnalyticsState()) {
    _load();
  }

  void _load() {
    state = AnalyticsState(
      heatmapThreshold: _prefs.getInt(_keyThreshold) ?? 5,
    );
  }

  Future<void> setHeatmapThreshold(int value) async {
    state = state.copyWith(heatmapThreshold: value);
    await _prefs.setInt(_keyThreshold, value);
  }

  static (String, String) dateRangeFor(AnalyticsPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case AnalyticsPeriod.day:
        final d = dateKey(now);
        return (d, d);
      case AnalyticsPeriod.week:
        final mon = now.subtract(Duration(days: now.weekday - 1));
        return (dateKey(mon), dateKey(now));
      case AnalyticsPeriod.month:
        final first = DateTime(now.year, now.month, 1);
        return (dateKey(first), dateKey(now));
      case AnalyticsPeriod.heatmap:
        final from = now.subtract(const Duration(days: 13));
        return (dateKey(from), dateKey(now));
    }
  }

  static String labelFor(AnalyticsPeriod period) {
    switch (period) {
      case AnalyticsPeriod.day:
        return '오늘';
      case AnalyticsPeriod.week:
        return '이번 주';
      case AnalyticsPeriod.month:
        return '이번 달';
      case AnalyticsPeriod.heatmap:
        return '히트맵';
    }
  }
}

final analyticsViewModelProvider =
    StateNotifierProvider<AnalyticsViewModel, AnalyticsState>(
        (ref) => AnalyticsViewModel(ref.read(sharedPrefsAdapterProvider)));
