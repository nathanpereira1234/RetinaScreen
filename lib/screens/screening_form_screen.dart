import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  // --- AI assist (decision support only) ---
  Uint8List? _fundusImage;
  RetinopathyPrediction? _prediction;
  FundusQuality? _quality;
  bool _grading = false;
  bool _duplicateWarning = false;

  /// Perceptual hash of the last image graded in this session — used to warn
  /// when the same photo is reused across patients/screenings.
  static List<bool>? _lastGradedHash;

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

  /// Pick a fundus image and run the on-device grader. The result is only a
  /// SUGGESTION — the human still confirms the dropdown before saving.
  Future<void> _analyzeFundus(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // Capture-quality gate: score the photo before grading so a bad capture is
    // caught and retaken, not silently graded. Pure on-device analysis.
    final quality = FundusQuality.assessBytes(bytes);
    // Duplicate detection: warn if this photo matches the last one graded.
    final hash = FundusAi.perceptualHashBytes(bytes);
    final duplicate = hash != null &&
        _lastGradedHash != null &&
        FundusAi.looksDuplicate(hash, _lastGradedHash!);
    if (hash != null) _lastGradedHash = hash;
    if (!mounted) return;
    setState(() {
      _fundusImage = bytes;
      _quality = quality;
      _duplicateWarning = duplicate;
      _grading = true;
      _prediction = null;
    });
    RetinopathyPrediction? pred;
    try {
      // Test-time augmentation (grade + horizontal flip, averaged) for a
      // steadier suggestion.
      pred = await ref.read(retinopathyGraderProvider).gradeEnsemble(bytes);
    } finally {
      if (mounted) setState(() => _grading = false);
    }
    if (!mounted) return;
    if (pred == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI model not available. Add assets/models/dr_model.tflite '
            '(see assets/models/README.md).',
          ),
        ),
      );
      return;
    }
    setState(() => _prediction = pred);
  }

  /// Apply the model's suggestion to the (human-owned) result field.
  void _useSuggestion(RetinopathyPrediction pred) {
    setState(() {
      _result = pred.suggestedResult;
      _referralStatus = _defaultStatusFor(_result);
    });
  }

  /// Show the Ben-Graham enhanced view of the captured image — clearer contrast
  /// and a fundus-cropped frame. Transparency, not a diagnosis.
  Future<void> _showEnhanced() async {
    final bytes = _fundusImage;
    if (bytes == null) return;
    final enhanced = FundusAi.enhanceBytes(bytes);
    if (enhanced == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enhanced view',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Image.memory(enhanced),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 365));
    // AI-suggested default date based on the result/referral state.
    final suggested =
        AttendanceAi.suggestReminderDate(_result, _referralStatus, from: now);
    final initial = suggested.isAfter(lastDate) ? lastDate : suggested;
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: lastDate,
      initialDate: initial,
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
    await HapticFeedback.mediumImpact();
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
            _buildAiAssist(),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ScreeningResult>(
              initialValue: _result,
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
              // Keyed so the programmatic default set when the result changes
              // is reflected (initialValue is otherwise read only once).
              key: ValueKey(_referralStatus),
              initialValue: _referralStatus,
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
            _SiteSuggestions(
              sites: ref.watch(referralSitesProvider).valueOrNull ??
                  const <String>[],
              onPick: (site) => setState(() => _site.text = site),
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

  /// The AI decision-support card. Lets the health worker analyse a fundus
  /// image and see a suggested grade — which they then confirm (or override) in
  /// the result dropdown below. The app never saves the model output directly.
  Widget _buildAiAssist() {
    final pred = _prediction;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI assist (suggestion only)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Analyses a fundus image on-device to suggest a grade. You must '
              'confirm the result yourself — the app does not diagnose.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_fundusImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Image.memory(
                  _fundusImage!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (_quality != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _QualityBanner(quality: _quality!),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _grading
                        ? null
                        : () => _analyzeFundus(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _grading
                        ? null
                        : () => _analyzeFundus(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            if (_duplicateWarning) ...[
              const SizedBox(height: AppSpacing.sm),
              const _MiniBanner(
                icon: Icons.copy_all_outlined,
                color: AppColors.ungradable,
                text: 'This looks like the same image as a previous screening.',
              ),
            ],
            if (_grading) ...[
              const SizedBox(height: AppSpacing.md),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_fundusImage != null && !_grading) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _showEnhanced,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Enhanced view'),
              ),
            ],
            if (pred != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Suggested: ${pred.grade.label}  '
                '(${(pred.confidence * 100).toStringAsFixed(0)}% confidence)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '→ maps to "${_resultLabels[pred.suggestedResult]}"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!pred.isConfident) ...[
                const SizedBox(height: AppSpacing.sm),
                const _MiniBanner(
                  icon: Icons.help_outline,
                  color: AppColors.ungradable,
                  text: 'AI is not confident — please grade this one manually.',
                ),
              ] else if (_quality?.verdict == FundusVerdict.poor) ...[
                const SizedBox(height: AppSpacing.sm),
                const _MiniBanner(
                  icon: Icons.image_not_supported_outlined,
                  color: AppColors.referable,
                  text: 'Image quality is poor — retake before trusting the AI.',
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonalIcon(
                  onPressed: () => _useSuggestion(pred),
                  icon: const Icon(Icons.check),
                  label: const Text('Use this suggestion'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Capture-quality feedback for a fundus photo: a coloured banner with the
/// verdict, the specific issues found, and a retake hint when it's poor.
class _QualityBanner extends ConsumerWidget {
  const _QualityBanner({required this.quality});

  final FundusQuality quality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final (label, color, icon) = switch (quality.verdict) {
      FundusVerdict.good => (s.qualityGood, AppColors.reached, Icons.check_circle),
      FundusVerdict.fair => (s.qualityFair, AppColors.ungradable, Icons.info),
      FundusVerdict.poor => (s.qualityPoor, AppColors.referable, Icons.error),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${s.imageQuality}: $label',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          if (quality.issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              quality.issues.map((i) => _issueLabel(s, i)).join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (quality.verdict == FundusVerdict.poor) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.retakeAdvised,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  static String _issueLabel(AppStrings s, FundusIssue issue) => switch (issue) {
        FundusIssue.tooDark => s.issueTooDark,
        FundusIssue.tooBright => s.issueTooBright,
        FundusIssue.blurry => s.issueBlurry,
        FundusIssue.lowField => s.issueLowField,
      };
}

/// Quick-fill chips for referral sites entered on earlier screenings.
class _SiteSuggestions extends StatelessWidget {
  const _SiteSuggestions({required this.sites, required this.onPick});

  final List<String> sites;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 0,
        children: [
          for (final site in sites.take(6))
            ActionChip(label: Text(site), onPressed: () => onPick(site)),
        ],
      ),
    );
  }
}

/// A compact coloured inline note (AI uncertainty, duplicate, quality).
class _MiniBanner extends StatelessWidget {
  const _MiniBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
