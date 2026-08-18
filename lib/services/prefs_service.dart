import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

/// Non-secret, non-clinical preferences: chosen UI language, theme, app-lock
/// on/off, and whether onboarding was seen. Secrets (the PIN hash) live in
/// [SecurityService], not here.
class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static const _kLanguage = 'app_language';
  static const _kLockEnabled = 'app_lock_enabled';
  static const _kThemeMode = 'theme_mode';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kTextScale = 'text_scale';
  static const _kAutoLockMinutes = 'auto_lock_minutes';

  AppLanguage get language =>
      AppLanguage.fromCode(_prefs.getString(_kLanguage));

  Future<void> setLanguage(AppLanguage language) =>
      _prefs.setString(_kLanguage, language.code);

  bool get lockEnabled => _prefs.getBool(_kLockEnabled) ?? false;

  Future<void> setLockEnabled(bool enabled) =>
      _prefs.setBool(_kLockEnabled, enabled);

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;

  Future<void> setOnboardingSeen(bool seen) =>
      _prefs.setBool(_kOnboardingSeen, seen);

  /// UI text scale, clamped to a sensible field range. 1.0 = default.
  double get textScale => (_prefs.getDouble(_kTextScale) ?? 1.0).clamp(0.8, 1.6);

  Future<void> setTextScale(double scale) =>
      _prefs.setDouble(_kTextScale, scale);

  /// Minutes the app may sit in the background before the lock re-engages.
  /// 0 = lock immediately when backgrounded.
  int get autoLockMinutes => _prefs.getInt(_kAutoLockMinutes) ?? 0;

  Future<void> setAutoLockMinutes(int minutes) =>
      _prefs.setInt(_kAutoLockMinutes, minutes);
}
