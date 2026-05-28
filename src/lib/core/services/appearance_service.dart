import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_block_style.dart';
import 'preferences_port.dart';

class AppearanceService extends StateNotifier<TimeBlockStyle> {
  static const _keyBlockStyle = 'appearance_block_style';

  final PreferencesPort _prefs;

  AppearanceService(this._prefs) : super(TimeBlockStyle.tintBar) {
    _load();
  }

  void _load() {
    final index = _prefs.getInt(_keyBlockStyle) ?? 0;
    state = TimeBlockStyle.values[index.clamp(0, TimeBlockStyle.values.length - 1)];
  }

  Future<void> setBlockStyle(TimeBlockStyle style) async {
    state = style;
    await _prefs.setInt(_keyBlockStyle, style.index);
  }
}

final appearanceServiceProvider =
    StateNotifierProvider<AppearanceService, TimeBlockStyle>(
        (ref) => AppearanceService(ref.read(sharedPrefsAdapterProvider)));
