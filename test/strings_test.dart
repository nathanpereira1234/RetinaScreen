import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/l10n/strings.dart';

void main() {
  test('every language defines the full English key set', () {
    final englishKeys = englishStrings.keys.toSet();
    for (final entry in allStringTables.entries) {
      final missing = englishKeys.difference(entry.value.keys.toSet());
      expect(
        missing,
        isEmpty,
        reason: '${entry.key.code} is missing keys: $missing',
      );
    }
  });

  test('no language has stray keys English lacks', () {
    final englishKeys = englishStrings.keys.toSet();
    for (final entry in allStringTables.entries) {
      final extra = entry.value.keys.toSet().difference(englishKeys);
      expect(extra, isEmpty, reason: '${entry.key.code} has extra keys: $extra');
    }
  });

  test('fromCode falls back to English for unknown codes', () {
    expect(AppLanguage.fromCode('hi'), AppLanguage.hi);
    expect(AppLanguage.fromCode('xx'), AppLanguage.en);
    expect(AppLanguage.fromCode(null), AppLanguage.en);
  });

  test('templated strings fill placeholders in every language', () {
    for (final lang in AppLanguage.values) {
      final s = AppStrings.of(lang);
      final withSite = s.reminderWithSite(name: 'Asha', site: 'Clinic');
      expect(withSite, contains('Asha'));
      expect(withSite, contains('Clinic'));
      expect(withSite, isNot(contains('{name}')));
      expect(withSite, isNot(contains('{site}')));

      expect(s.markStatus('Referred'), contains('Referred'));
    }
  });

  test('missing key falls back to English, never blank', () {
    const partial = AppStrings(AppLanguage.hi, {});
    expect(partial.appTitle, englishStrings['appTitle']);
  });
}
