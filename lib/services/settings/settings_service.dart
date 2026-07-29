import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class SettingsService {
  static const _themeKey = 'theme_mode';
  static const _nameKey = 'display_name';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  AppThemeMode get themeMode {
    final value = _prefs?.getString(_themeKey) ?? 'system';
    return AppThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await init();
    await _prefs!.setString(_themeKey, mode.name);
  }

  String get displayName => _prefs?.getString(_nameKey) ?? 'User';

  Future<void> setDisplayName(String name) async {
    await init();
    await _prefs!.setString(_nameKey, name.trim());
  }
}
