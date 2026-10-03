import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persists the settings with shared_preferences.
/// (The timetable itself is stored as a file by `TimetableService`.)
class SettingsService {
  static const _kSettings = 'settings_v1';

  final SharedPreferences _prefs;
  SettingsService(this._prefs);

  AppSettings loadSettings() {
    final s = _prefs.getString(_kSettings);
    if (s == null) return const AppSettings();
    try {
      return AppSettings.decode(s);
    } catch (_) {
      return const AppSettings(); // corrupted data must never stop the display
    }
  }

  Future<void> saveSettings(AppSettings s) => _prefs.setString(_kSettings, s.encode());
}
