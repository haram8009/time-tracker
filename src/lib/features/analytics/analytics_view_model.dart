import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/date_key.dart';
import '../../core/services/preferences_port.dart';

enum AnalyticsPeriod { day, week, month, heatmap }

class AnalyticsState {
  final int heatmapThreshold;
  final DateKey anchorDate;

  AnalyticsState({this.heatmapThreshold = 5, DateKey? anchorDate})
      : anchorDate = anchorDate ?? DateKey.today();

  AnalyticsState copyWith({int? heatmapThreshold, DateKey? anchorDate}) =>
      AnalyticsState(
        heatmapThreshold: heatmapThreshold ?? this.heatmapThreshold,
        anchorDate: anchorDate ?? this.anchorDate,
      );
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  static const _keyThreshold = 'heatmap_threshold';
  static const _keyAnchor = 'analytics_anchor';

  final PreferencesPort _prefs;

  AnalyticsViewModel(this._prefs) : super(AnalyticsState()) {
    _load();
  }

  void _load() {
    final today = DateKey.today();
    DateKey anchor = today;
    final page = _prefs.getInt(_keyAnchor);
    if (page != null) {
      final stored = DateKey.fromPage(page, DateKey.appEpoch);
      anchor = stored.isAfter(today) ? today : stored;
    }
    state = AnalyticsState(
      heatmapThreshold: _prefs.getInt(_keyThreshold) ?? 5,
      anchorDate: anchor,
    );
  }

  Future<void> setHeatmapThreshold(int value) async {
    state = state.copyWith(heatmapThreshold: value);
    await _prefs.setInt(_keyThreshold, value);
  }

  Future<void> goToDate(DateKey date) async {
    final today = DateKey.today();
    final capped = date.isAfter(today) ? today : date;
    state = state.copyWith(anchorDate: capped);
    await _prefs.setInt(_keyAnchor, capped.toPage(DateKey.appEpoch));
  }

  Future<void> goToToday() => goToDate(DateKey.today());

  /// Returns inclusive (from, to) date range for [period] anchored on [anchor].
  /// End is capped at today (no future data).
  static (DateKey, DateKey) dateRangeFor(AnalyticsPeriod period, DateKey anchor) {
    final today = DateKey.today();
    final a = anchor.toDateTime();
    switch (period) {
      case AnalyticsPeriod.day:
        return (anchor, anchor);
      case AnalyticsPeriod.week:
        final mon = a.subtract(Duration(days: a.weekday - 1));
        final sun = mon.add(const Duration(days: 6));
        return (DateKey.fromDateTime(mon), _minToday(DateKey.fromDateTime(sun), today));
      case AnalyticsPeriod.month:
        final first = DateTime(a.year, a.month, 1);
        final last = DateTime(a.year, a.month + 1, 0);
        return (DateKey.fromDateTime(first), _minToday(DateKey.fromDateTime(last), today));
      case AnalyticsPeriod.heatmap:
        final from = a.subtract(const Duration(days: 13));
        return (DateKey.fromDateTime(from), anchor);
    }
  }

  static DateKey _minToday(DateKey end, DateKey today) =>
      end.isAfter(today) ? today : end;

  static String labelFor(AnalyticsPeriod period, DateKey anchor) {
    final today = DateKey.today();
    switch (period) {
      case AnalyticsPeriod.day:
        return anchor == today ? '오늘' : '${anchor.month}월 ${anchor.day}일';
      case AnalyticsPeriod.week:
        final (from, to) = dateRangeFor(AnalyticsPeriod.week, anchor);
        final (curFrom, _) = dateRangeFor(AnalyticsPeriod.week, today);
        if (from == curFrom) return '이번 주';
        return '${from.month}/${from.day}~${to.month}/${to.day}';
      case AnalyticsPeriod.month:
        if (anchor.year == today.year && anchor.month == today.month) {
          return '이번 달';
        }
        return '${anchor.year}년 ${anchor.month}월';
      case AnalyticsPeriod.heatmap:
        final (from, to) = dateRangeFor(AnalyticsPeriod.heatmap, anchor);
        return '${from.month}/${from.day}~${to.month}/${to.day}';
    }
  }
}

final analyticsViewModelProvider =
    StateNotifierProvider<AnalyticsViewModel, AnalyticsState>(
        (ref) => AnalyticsViewModel(ref.read(sharedPrefsAdapterProvider)));
