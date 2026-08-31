import 'package:shared_preferences/shared_preferences.dart';

/// persisted user flags/choices: onboarding done, language, theme mode.
///
/// Everything here is tiny key/value data, which is exactly what
/// [SharedPreferences] is for; anything relational lives in SQLite.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _kOnboarded = 'onboarded';
  static const _kLanguageCode = 'language_code';
  static const _kThemeMode = 'theme_mode';

  bool get isOnboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);

  /// Saved language code ('am' or 'en'); null means "follow system".
  String? get languageCode => _prefs.getString(_kLanguageCode);

  Future<void> setLanguageCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLanguageCode);
    } else {
      await _prefs.setString(_kLanguageCode, code);
    }
  }

  /// Saved theme mode name ('system' | 'light' | 'dark'); null = system.
  String? get themeModeName => _prefs.getString(_kThemeMode);

  Future<void> setThemeModeName(String? name) async {
    if (name == null) {
      await _prefs.remove(_kThemeMode);
    } else {
      await _prefs.setString(_kThemeMode, name);
    }
  }
}
