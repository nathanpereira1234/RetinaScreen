import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'activity_log_screen.dart';

/// Settings: language, app lock (PIN/biometric), and an about note that keeps
/// the "does not diagnose" line visible.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final currentLang = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final prefs = ref.watch(prefsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          _SectionHeader(s.languageLabel),
          for (final lang in AppLanguage.values)
            ListTile(
              title: Text(lang.label),
              leading: Icon(
                lang == currentLang
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: lang == currentLang ? AppColors.primary : null,
              ),
              onTap: () => ref.read(localeProvider.notifier).set(lang),
            ),
          const Divider(),
          _SectionHeader(s.appearance),
          for (final (mode, label) in <(ThemeMode, String)>[
            (ThemeMode.system, s.themeSystem),
            (ThemeMode.light, s.themeLight),
            (ThemeMode.dark, s.themeDark),
          ])
            ListTile(
              title: Text(label),
              leading: Icon(
                mode == themeMode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: mode == themeMode ? AppColors.primary : null,
              ),
              onTap: () => ref.read(themeModeProvider.notifier).set(mode),
            ),
          const Divider(),
          _SectionHeader(s.textSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    value: ref.watch(textScaleProvider),
                    label: '${(ref.watch(textScaleProvider) * 100).round()}%',
                    onChanged: (v) =>
                        ref.read(textScaleProvider.notifier).set(v),
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(s.security),
          SwitchListTile(
            title: Text(s.appLock),
            subtitle: Text(s.appLockSubtitle),
            value: prefs.lockEnabled,
            onChanged: (on) => _toggleLock(on),
          ),
          if (prefs.lockEnabled) ...[
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: Text(s.changePin),
              onTap: _setPin,
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(s.autoLock),
              trailing: Text(_autoLockLabel(s, prefs.autoLockMinutes)),
              onTap: () => _pickAutoLock(prefs),
            ),
          ],
          const Divider(),
          _SectionHeader(s.about),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.activityLog),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActivityLogScreen(),
              ),
            ),
          ),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: 'RetinaScreen',
            applicationVersion: 'v$_appVersion',
            applicationLegalese: '© RetinaScreen',
            aboutBoxChildren: [
              const SizedBox(height: AppSpacing.md),
              Text(s.doesNotDiagnose),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              s.doesNotDiagnose,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  static const _appVersion = '0.1.0';

  String _autoLockLabel(AppStrings s, int minutes) =>
      minutes == 0 ? s.immediately : '$minutes min';

  Future<void> _pickAutoLock(PrefsService prefs) async {
    final s = ref.read(stringsProvider);
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in const [0, 1, 5, 15])
              ListTile(
                title: Text(_autoLockLabel(s, m)),
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await prefs.setAutoLockMinutes(choice);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleLock(bool on) async {
    final prefs = ref.read(prefsServiceProvider);
    final security = ref.read(securityServiceProvider);
    if (on && !await security.hasPin()) {
      final set = await _setPin();
      if (!set) return; // user cancelled — leave the lock off
    }
    await prefs.setLockEnabled(on);
    if (mounted) setState(() {}); // reflect the new switch state
  }

  /// Prompt for a new PIN (entered twice). Returns true when a PIN was saved.
  Future<bool> _setPin() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SetPinDialog(
        strings: ref.read(stringsProvider),
        security: ref.read(securityServiceProvider),
      ),
    );
    return saved ?? false;
  }
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog({required this.strings, required this.security});

  final AppStrings strings;
  final SecurityService security;

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = widget.strings;
    final pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = s.enterPin);
      return;
    }
    if (pin != _confirm.text.trim()) {
      setState(() => _error = s.pinsDoNotMatch);
      return;
    }
    await widget.security.setPin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.setPin),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_pin, s.setPin),
          const SizedBox(height: AppSpacing.sm),
          _field(_confirm, s.confirmPin),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.referable)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _save, child: Text(s.setPin)),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        decoration: InputDecoration(labelText: label),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}
