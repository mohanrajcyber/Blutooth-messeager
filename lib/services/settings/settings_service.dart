import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';

enum AppThemeMode { light, dark, system }

class SettingsService {
  static const _themeKey = 'theme_mode';
  static const _nameKey = 'display_name';
  static const _langKey = 'language';
  static const _pinHashKey = 'pin_hash';
  static const _lockEnabledKey = 'lock_enabled';
  static const _disappearingKey = 'disappearing_24h';
  static const _soundKey = 'sound_enabled';
  static const _vibrateKey = 'vibrate_enabled';
  static const _bubbleColorKey = 'bubble_color';
  static const _wallpaperKey = 'chat_wallpaper';
  static const _avatarKey = 'profile_avatar';
  static const _lastSeenKey = 'last_seen';

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

  AppStrings get strings {
    final lang = _prefs?.getString(_langKey) ?? 'en';
    return lang == 'ta' ? AppStrings.ta : AppStrings.en;
  }

  Future<void> setLanguage(String code) async {
    await init();
    await _prefs!.setString(_langKey, code);
  }

  bool get lockEnabled => _prefs?.getBool(_lockEnabledKey) ?? false;

  Future<void> setLockEnabled(bool v) async {
    await init();
    await _prefs!.setBool(_lockEnabledKey, v);
  }

  String? get pinHash => _prefs?.getString(_pinHashKey);

  Future<void> setPinHash(String? hash) async {
    await init();
    if (hash == null) {
      await _prefs!.remove(_pinHashKey);
    } else {
      await _prefs!.setString(_pinHashKey, hash);
    }
  }

  bool get disappearing24h => _prefs?.getBool(_disappearingKey) ?? false;

  Future<void> setDisappearing24h(bool v) async {
    await init();
    await _prefs!.setBool(_disappearingKey, v);
  }

  bool get soundEnabled => _prefs?.getBool(_soundKey) ?? true;

  Future<void> setSoundEnabled(bool v) async {
    await init();
    await _prefs!.setBool(_soundKey, v);
  }

  bool get vibrateEnabled => _prefs?.getBool(_vibrateKey) ?? true;

  Future<void> setVibrateEnabled(bool v) async {
    await init();
    await _prefs!.setBool(_vibrateKey, v);
  }

  String? get bubbleColor => _prefs?.getString(_bubbleColorKey);

  Future<void> setBubbleColor(String? color) async {
    await init();
    if (color == null) {
      await _prefs!.remove(_bubbleColorKey);
    } else {
      await _prefs!.setString(_bubbleColorKey, color);
    }
  }

  String? get chatWallpaper => _prefs?.getString(_wallpaperKey);

  Future<void> setChatWallpaper(String? path) async {
    await init();
    if (path == null) {
      await _prefs!.remove(_wallpaperKey);
    } else {
      await _prefs!.setString(_wallpaperKey, path);
    }
  }

  String? get profileAvatar => _prefs?.getString(_avatarKey);

  Future<void> setProfileAvatar(String? path) async {
    await init();
    if (path == null) {
      await _prefs!.remove(_avatarKey);
    } else {
      await _prefs!.setString(_avatarKey, path);
    }
  }

  DateTime? get myLastSeen {
    final ms = _prefs?.getInt(_lastSeenKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setMyLastSeen(DateTime time) async {
    await init();
    await _prefs!.setInt(_lastSeenKey, time.millisecondsSinceEpoch);
  }
}
