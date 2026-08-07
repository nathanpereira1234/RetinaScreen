import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Record a screening result for a patient (A14).
///
/// The result is entered by a human — the app does not diagnose. Saving wires
/// the reminder engine (A16): a follow-up date on a still-pending referral is
/// scheduled as a notification that deep-links back to the patient.
class ScreeningFormScreen extends ConsumerStatefulWidget {
  const ScreeningFormScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final int patientId;
  final String patientName;

  @override
  ConsumerState<ScreeningFormScreen> createState() =>
      _ScreeningFormScreenState();
}

class _ScreeningFormScreenState extends ConsumerState<ScreeningFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ScreeningResult _result = ScreeningResult.referable;
  late ReferralStatus _referralStatus;
  final _site = TextEditingController();
  final _notes = TextEditingController();
  final DateTime _screeningDate = DateTime.now();
  DateTime? _reminderAt;
  bool _saving = false;

  static const Map<ScreeningResult, String> _resultLabels = {
    ScreeningResult.referable: 'Referable — refer to ophthalmologist',
    ScreeningResult.notReferable: 'Not referable',
    ScreeningResult.ungradable: 'Ungradable — re-screen',
  };

  @override
  void initState() {
    super.initState();
    _referralStatus = _defaultStatusFor(_result);
  }

  ReferralStatus _defaultStatusFor(ScreeningResult r) =>
      r == ScreeningResult.referable
          ? ReferralStatus.referred
          : ReferralStatus.none;

  @override
  void dispose() {
    _site.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    setState(() => _reminderAt = DateTime(date.year, date.month, date.day, 9));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(patientRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    final site = _site.text.trim();
    final notes = _notes.text.trim();
    try {
      final screeningId = await repo.addScreening(
        patientId: widget.patientId,
        result: _result,
        referralStatus: _referralStatus,
        referralSite: site.isEmpty ? null : site,
        screeningDate: _screeningDate,
        nextReminderAt: _reminderAt,
        notes: notes.isEmpty ? null : notes,
      );
      final reminderAt = _reminderAt;
      if (reminderAt != null && !_referralStatus.hasReachedClinic) {
        await notifications.schedule(
          id: screeningId,
          title: 'Follow-up due',
          body: '${widget.patientName} has a pending eye-clinic referral.',
          when: reminderAt,
          patientId: widget.patientId,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Screening — ${widget.patientName}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            DropdownButtonFormField<ScreeningResult>(
              value: _result,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Result (entered by a human)',
              ),
              items: [
                for (final r in ScreeningResult.values)
                  DropdownMenuItem(value: r, child: Text(_resultLabels[r]!)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _result = v;
                  _referralStatus = _defaultStatusFor(v);
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ReferralStatus>(
              value: _referralStatus,
              decoration:
                  const InputDecoration(labelText: 'Referral status'),
              items: [
                for (final s in ReferralStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (v) =>
                  setState(() => _referralStatus = v ?? ReferralStatus.none),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _site,
              decoration: const InputDecoration(
                labelText: 'Referral site / clinic (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Follow-up reminder'),
              subtitle: Text(
                _reminderAt == null ? 'None set' : _formatDate(_reminderAt!),
              ),
              trailing: TextButton(
                onPressed: _pickReminder,
                child: Text(_reminderAt == null ? 'Set date' : 'Change'),
              ),
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
                  : const Text('Save screening'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
