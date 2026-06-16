import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/features/analytics/analytics_view_model.dart';

class _FakePrefs implements PreferencesPort {
  final Map<String, Object> _store = {};

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  Future<void> setBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _store[key] = value;
}

void main() {
  group('AnalyticsViewModel', () {
    test('기본 heatmapThreshold = 5', () {
      final vm = AnalyticsViewModel(_FakePrefs());
      expect(vm.state.heatmapThreshold, 5);
    });

    test('저장된 threshold 로드', () {
      final prefs = _FakePrefs().._store['heatmap_threshold'] = 10;
      final vm = AnalyticsViewModel(prefs);
      expect(vm.state.heatmapThreshold, 10);
    });

    test('setHeatmapThreshold → state 변경 + prefs 저장', () async {
      final prefs = _FakePrefs();
      final vm = AnalyticsViewModel(prefs);
      await vm.setHeatmapThreshold(8);
      expect(vm.state.heatmapThreshold, 8);
      expect(prefs.getInt('heatmap_threshold'), 8);
    });

    group('anchor 탐색 + persist', () {
      test('기본 anchor = 오늘', () {
        final vm = AnalyticsViewModel(_FakePrefs());
        expect(vm.state.anchorDate, DateKey.today());
      });

      test('goToDate → state 변경 + page 정수 persist', () async {
        final prefs = _FakePrefs();
        final vm = AnalyticsViewModel(prefs);
        final past = const DateKey(2026, 3, 10);
        await vm.goToDate(past);
        expect(vm.state.anchorDate, past);
        expect(prefs.getInt('analytics_anchor'),
            past.toPage(DateKey.appEpoch));
      });

      test('goToDate 미래 입력 → 오늘로 cap', () async {
        final vm = AnalyticsViewModel(_FakePrefs());
        final future = DateKey.today().add(const Duration(days: 30));
        await vm.goToDate(future);
        expect(vm.state.anchorDate, DateKey.today());
      });

      test('저장된 anchor 복원', () {
        final past = const DateKey(2026, 2, 1);
        final prefs = _FakePrefs()
          .._store['analytics_anchor'] = past.toPage(DateKey.appEpoch);
        final vm = AnalyticsViewModel(prefs);
        expect(vm.state.anchorDate, past);
      });

      test('저장된 미래 anchor → 오늘로 cap', () {
        final future = DateKey.today().add(const Duration(days: 10));
        final prefs = _FakePrefs()
          .._store['analytics_anchor'] = future.toPage(DateKey.appEpoch);
        final vm = AnalyticsViewModel(prefs);
        expect(vm.state.anchorDate, DateKey.today());
      });

      test('goToToday → anchor 오늘 복귀', () async {
        final vm = AnalyticsViewModel(_FakePrefs());
        await vm.goToDate(const DateKey(2025, 1, 1));
        await vm.goToToday();
        expect(vm.state.anchorDate, DateKey.today());
      });
    });

    group('dateRangeFor (anchor 기반)', () {
      test('day → anchor 날짜 쌍', () {
        final anchor = const DateKey(2026, 3, 10);
        final (start, end) =
            AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.day, anchor);
        expect(start, anchor);
        expect(end, anchor);
      });

      test('과거 week → 월요일~일요일 완전 7일', () {
        // 2026-03-10 = 화요일
        final anchor = const DateKey(2026, 3, 10);
        final (start, end) =
            AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.week, anchor);
        expect(start, const DateKey(2026, 3, 9)); // 월
        expect(end, const DateKey(2026, 3, 15)); // 일
        final diff = end.toDateTime().difference(start.toDateTime()).inDays;
        expect(diff, 6);
      });

      test('과거 month → 1일~말일 완전 구간', () {
        final anchor = const DateKey(2026, 2, 15);
        final (start, end) =
            AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.month, anchor);
        expect(start, const DateKey(2026, 2, 1));
        expect(end, const DateKey(2026, 2, 28));
      });

      test('현재 month → today에서 cap', () {
        final today = DateKey.today();
        final (start, end) =
            AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.month, today);
        expect(start, DateKey(today.year, today.month, 1));
        expect(end, today);
      });

      test('heatmap → anchor 기준 14일 범위', () {
        final anchor = const DateKey(2026, 3, 10);
        final (start, end) =
            AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.heatmap, anchor);
        expect(end, anchor);
        final diff = end.toDateTime().difference(start.toDateTime()).inDays;
        expect(diff, 13);
      });
    });

    group('labelFor (anchor 기반)', () {
      final today = DateKey.today();

      test('day 오늘 → "오늘"', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.day, today), '오늘');
      });
      test('day 과거 → "M월 D일"', () {
        expect(
            AnalyticsViewModel.labelFor(
                AnalyticsPeriod.day, const DateKey(2026, 3, 10)),
            '3월 10일');
      });
      test('week 이번 주 → "이번 주"', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.week, today), '이번 주');
      });
      test('month 이번 달 → "이번 달"', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.month, today), '이번 달');
      });
      test('month 과거 → "Y년 M월"', () {
        expect(
            AnalyticsViewModel.labelFor(
                AnalyticsPeriod.month, const DateKey(2026, 2, 15)),
            '2026년 2월');
      });
    });
  });
}
