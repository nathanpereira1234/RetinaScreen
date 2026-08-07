import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Add or edit a patient (A13). Validates a required name, a plausible phone,
/// and a sane age, then persists via the repository.
class PatientFormScreen extends ConsumerStatefulWidget {
  const PatientFormScreen({super.key, this.existing});

  /// When non-null, the form edits this patient instead of adding a new one.
  final Patient? existing;

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _age;
  String? _sex;
  late String _language;
  bool _saving = false;

  static const Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'mr': 'Marathi',
  };
  static const List<String> _sexes = ['Female', 'Male', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _age = TextEditingController(text: e?.age?.toString() ?? '');
    _sex = e?.sex;
    _language = e?.preferredLanguage ?? 'en';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(patientRepositoryProvider);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final age = int.tryParse(_age.text.trim());
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repo.addPatient(
          name: name,
          phone: phone,
          age: age,
          sex: _sex,
          preferredLanguage: _language,
        );
      } else {
        await repo.editPatient(
          existing: existing,
          name: name,
          phone: phone,
          age: age,
          sex: _sex,
          preferredLanguage: _language,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit patient' : 'Add patient')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Phone is required';
                final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 7) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (optional)'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                if (n == null || n < 0 || n > 120) return 'Enter a valid age';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              value: _sex,
              decoration: const InputDecoration(labelText: 'Sex (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('Not specified'),
                ),
                for (final s in _sexes)
                  DropdownMenuItem<String?>(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _language,
              decoration:
                  const InputDecoration(labelText: 'Preferred language'),
              items: [
                for (final e in _languages.entries)
                  DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'en'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save changes' : 'Add patient'),
            ),
          ],
        ),
      ),
    );
  }
}
