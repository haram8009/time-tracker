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

    group('dateRangeFor', () {
      test('day → 오늘 날짜 쌍', () {
        final (start, end) = AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.day);
        expect(start, end);
      });

      test('week → 월요일 ~ 오늘', () {
        final (start, end) = AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.week);
        expect(start, isA<DateKey>());
        expect(end, isA<DateKey>());
        expect(start.isBefore(end) || start == end, isTrue);
      });

      test('heatmap → 14일 범위', () {
        final (start, end) = AnalyticsViewModel.dateRangeFor(AnalyticsPeriod.heatmap);
        final diff = end.toDateTime().difference(start.toDateTime()).inDays;
        expect(diff, 13);
      });
    });

    group('labelFor', () {
      test('day → 오늘', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.day), '오늘');
      });
      test('week → 이번 주', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.week), '이번 주');
      });
      test('month → 이번 달', () {
        expect(AnalyticsViewModel.labelFor(AnalyticsPeriod.month), '이번 달');
      });
    });
  });
}
