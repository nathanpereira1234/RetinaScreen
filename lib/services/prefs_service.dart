import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

/// Non-secret, non-clinical preferences: the chosen UI language and whether the
/// app lock is on. Secrets (the DB key, the PIN) live in [SecurityService], not
/// here.
class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static const _kLanguage = 'app_language';
  static const _kLockEnabled = 'app_lock_enabled';

  AppLanguage get language =>
      AppLanguage.fromCode(_prefs.getString(_kLanguage));

  Future<void> setLanguage(AppLanguage language) =>
      _prefs.setString(_kLanguage, language.code);

  bool get lockEnabled => _prefs.getBool(_kLockEnabled) ?? false;

  Future<void> setLockEnabled(bool enabled) =>
      _prefs.setBool(_kLockEnabled, enabled);
}
