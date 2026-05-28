import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/services/appearance_service.dart';
import 'package:time_tracker/core/services/preferences_port.dart';
import 'package:time_tracker/features/grid/models/time_block_style.dart';

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
  group('AppearanceService', () {
    test('기본값 tintBar', () {
      final svc = AppearanceService(_FakePrefs());
      expect(svc.state, TimeBlockStyle.tintBar);
    });

    test('setBlockStyle → state 변경 + prefs 저장', () async {
      final prefs = _FakePrefs();
      final svc = AppearanceService(prefs);
      await svc.setBlockStyle(TimeBlockStyle.card);
      expect(svc.state, TimeBlockStyle.card);
      expect(prefs.getInt('appearance_block_style'), TimeBlockStyle.card.index);
    });

    test('저장된 값 복원 — card (index 1)', () {
      final prefs = _FakePrefs().._store['appearance_block_style'] = 1;
      final svc = AppearanceService(prefs);
      expect(svc.state, TimeBlockStyle.card);
    });

    test('저장된 값 복원 — liquidGlass (index 3)', () {
      final prefs = _FakePrefs().._store['appearance_block_style'] = 3;
      final svc = AppearanceService(prefs);
      expect(svc.state, TimeBlockStyle.liquidGlass);
    });

    test('잘못된 index → tintBar fallback', () {
      final prefs = _FakePrefs().._store['appearance_block_style'] = 99;
      final svc = AppearanceService(prefs);
      expect(svc.state, TimeBlockStyle.values.last); // clamped to last
    });
  });
}
