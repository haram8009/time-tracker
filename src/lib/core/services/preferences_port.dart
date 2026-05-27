import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PreferencesPort {
  bool? getBool(String key);
  int? getInt(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
}

class SharedPrefsAdapter implements PreferencesPort {
  final SharedPreferences _prefs;

  SharedPrefsAdapter(this._prefs);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
}

final sharedPrefsAdapterProvider = Provider<PreferencesPort>((ref) {
  throw UnimplementedError('SharedPrefsAdapter must be overridden in ProviderScope');
});
